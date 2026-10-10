package io.github.ramlakhanmadheshiya.onecleanshot.video;

import android.app.Activity;
import android.content.ContentResolver;
import android.content.ContentValues;
import android.content.Intent;
import android.media.Image;
import android.media.MediaCodec;
import android.media.MediaCodecInfo;
import android.media.MediaFormat;
import android.media.MediaMuxer;
import android.net.Uri;
import android.os.Build;
import android.provider.MediaStore;

import androidx.annotation.NonNull;
import androidx.core.content.FileProvider;

import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.UsedByGodot;

import java.io.File;
import java.io.FileInputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.io.RandomAccessFile;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.util.ArrayList;
import java.util.List;

/**
 * Turns the game's share replay into an MP4: frames rendered by Godot (RGBA) are
 * encoded to H.264, a music bed (16-bit PCM WAV) to AAC, and both are muxed into
 * one file, which can then be saved to the gallery or shared.
 *
 * GDScript use: begin(path, w, h, fps, frames, wav) -> addFrame(rgba) x frames ->
 * finish() -> saveToGallery(path, name) / share(path, text).
 */
public class OCSVideoPlugin extends GodotPlugin {
	private static final String VIDEO_MIME = "video/avc";
	private static final String AUDIO_MIME = "audio/mp4a-latm";
	private static final long TIMEOUT_US = 10_000;

	private MediaCodec video;
	private MediaMuxer muxer;
	private int videoTrack = -1;
	private int audioTrack = -1;
	private boolean muxerStarted;
	private int width;
	private int height;
	private int fps;
	private int frameIndex;
	private final MediaCodec.BufferInfo info = new MediaCodec.BufferInfo();
	private final List<byte[]> audioData = new ArrayList<>();
	private final List<MediaCodec.BufferInfo> audioInfo = new ArrayList<>();
	private MediaFormat audioFormat;
	private String error = "";

	public OCSVideoPlugin(Godot godot) {
		super(godot);
	}

	@NonNull
	@Override
	public String getPluginName() {
		return "OCSVideo";
	}

	@UsedByGodot
	public String lastError() {
		return error;
	}

	/** Starts a video of `frames` frames at `fps`. `wavPath` may be empty for no sound. */
	@UsedByGodot
	public boolean begin(String path, int w, int h, int framesPerSecond, int frames, String wavPath) {
		try {
			release();
			error = "";
			width = w;
			height = h;
			fps = framesPerSecond;
			frameIndex = 0;
			audioData.clear();
			audioInfo.clear();
			audioFormat = null;
			if (wavPath != null && !wavPath.isEmpty()) {
				try {
					encodeAudio(wavPath, (long) frames * 1_000_000L / fps);
				} catch (Exception e) {
					// A silent video is better than none.
					audioData.clear();
					audioInfo.clear();
					audioFormat = null;
				}
			}
			MediaFormat f = MediaFormat.createVideoFormat(VIDEO_MIME, w, h);
			f.setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420Flexible);
			f.setInteger(MediaFormat.KEY_BIT_RATE, 5_000_000);
			f.setInteger(MediaFormat.KEY_FRAME_RATE, fps);
			f.setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1);
			video = MediaCodec.createEncoderByType(VIDEO_MIME);
			video.configure(f, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE);
			video.start();
			muxer = new MediaMuxer(path, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4);
			videoTrack = -1;
			audioTrack = -1;
			muxerStarted = false;
			return true;
		} catch (Exception e) {
			error = "begin: " + e;
			release();
			return false;
		}
	}

	/** Adds one frame: width * height * 4 bytes of RGBA. */
	@UsedByGodot
	public boolean addFrame(byte[] rgba) {
		if (video == null) {
			return false;
		}
		try {
			int index;
			int spins = 0;
			while ((index = video.dequeueInputBuffer(TIMEOUT_US)) < 0) {
				drain(false);
				if (++spins > 500) {
					error = "encoder stalled";
					return false;
				}
			}
			Image img = video.getInputImage(index);
			int size = width * height * 3 / 2;
			if (img != null) {
				fillImage(img, rgba);
			} else {
				ByteBuffer buf = video.getInputBuffer(index);
				fillI420(buf, rgba);
			}
			long pts = (long) frameIndex * 1_000_000L / fps;
			video.queueInputBuffer(index, 0, size, pts, 0);
			frameIndex++;
			drain(false);
			return true;
		} catch (Exception e) {
			error = "addFrame: " + e;
			return false;
		}
	}

	/** Ends the stream and writes the file. */
	@UsedByGodot
	public boolean finish() {
		if (video == null) {
			return false;
		}
		try {
			int index;
			int spins = 0;
			while ((index = video.dequeueInputBuffer(TIMEOUT_US)) < 0) {
				drain(false);
				if (++spins > 500) {
					break;
				}
			}
			if (index >= 0) {
				video.queueInputBuffer(index, 0, 0, (long) frameIndex * 1_000_000L / fps, MediaCodec.BUFFER_FLAG_END_OF_STREAM);
			}
			drain(true);
			if (muxerStarted) {
				muxer.stop();
			}
			boolean ok = muxerStarted;
			release();
			if (!ok) {
				error = "no frames were encoded";
			}
			return ok;
		} catch (Exception e) {
			error = "finish: " + e;
			release();
			return false;
		}
	}

	/** Copies the video into the gallery under Movies/One Clean Shot (Android 10+). */
	@UsedByGodot
	public boolean saveToGallery(String path, String displayName) {
		Activity activity = getActivity();
		if (activity == null || Build.VERSION.SDK_INT < 29) {
			error = "saving to the gallery needs Android 10 or newer";
			return false;
		}
		try {
			ContentResolver resolver = activity.getContentResolver();
			ContentValues values = new ContentValues();
			values.put(MediaStore.MediaColumns.DISPLAY_NAME, displayName);
			values.put(MediaStore.MediaColumns.MIME_TYPE, "video/mp4");
			values.put(MediaStore.MediaColumns.RELATIVE_PATH, "Movies/One Clean Shot");
			values.put(MediaStore.MediaColumns.IS_PENDING, 1);
			Uri uri = resolver.insert(MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY), values);
			if (uri == null) {
				error = "the gallery refused the file";
				return false;
			}
			try (InputStream in = new FileInputStream(path); OutputStream out = resolver.openOutputStream(uri)) {
				byte[] buf = new byte[64 * 1024];
				int n;
				while ((n = in.read(buf)) > 0) {
					out.write(buf, 0, n);
				}
			}
			values.clear();
			values.put(MediaStore.MediaColumns.IS_PENDING, 0);
			resolver.update(uri, values, null, null);
			return true;
		} catch (Exception e) {
			error = "save: " + e;
			return false;
		}
	}

	/** Opens the system share sheet with the video and a message. */
	@UsedByGodot
	public boolean share(String path, String text) {
		final Activity activity = getActivity();
		if (activity == null) {
			return false;
		}
		try {
			Uri uri = FileProvider.getUriForFile(activity, activity.getPackageName() + ".fileprovider", new File(path));
			Intent send = new Intent(Intent.ACTION_SEND);
			send.setType("video/mp4");
			send.putExtra(Intent.EXTRA_STREAM, uri);
			send.putExtra(Intent.EXTRA_TEXT, text);
			send.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
			final Intent chooser = Intent.createChooser(send, "Share your shot");
			chooser.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
			activity.runOnUiThread(() -> activity.startActivity(chooser));
			return true;
		} catch (Exception e) {
			error = "share: " + e;
			return false;
		}
	}

	// --- Video ------------------------------------------------------------------

	private void drain(boolean endOfStream) {
		int idle = 0;
		while (true) {
			int out = video.dequeueOutputBuffer(info, endOfStream ? TIMEOUT_US : 0);
			if (out == MediaCodec.INFO_TRY_AGAIN_LATER) {
				if (!endOfStream || ++idle > 300) {
					return;
				}
			} else if (out == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
				if (!muxerStarted) {
					videoTrack = muxer.addTrack(video.getOutputFormat());
					if (audioFormat != null) {
						audioTrack = muxer.addTrack(audioFormat);
					}
					muxer.start();
					muxerStarted = true;
					writeAudio();
				}
			} else if (out >= 0) {
				ByteBuffer data = video.getOutputBuffer(out);
				if ((info.flags & MediaCodec.BUFFER_FLAG_CODEC_CONFIG) != 0) {
					info.size = 0;
				}
				if (info.size > 0 && muxerStarted && data != null) {
					data.position(info.offset);
					data.limit(info.offset + info.size);
					muxer.writeSampleData(videoTrack, data, info);
				}
				video.releaseOutputBuffer(out, false);
				if ((info.flags & MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) {
					return;
				}
			}
		}
	}

	private static int clamp(int v) {
		return v < 0 ? 0 : (v > 255 ? 255 : v);
	}

	/** RGBA to YUV 4:2:0 (BT.601) into the encoder's image, whatever its layout. */
	private void fillImage(Image img, byte[] rgba) {
		Image.Plane[] planes = img.getPlanes();
		ByteBuffer yb = planes[0].getBuffer();
		ByteBuffer ub = planes[1].getBuffer();
		ByteBuffer vb = planes[2].getBuffer();
		int yRow = planes[0].getRowStride();
		int yPix = planes[0].getPixelStride();
		int uRow = planes[1].getRowStride();
		int uPix = planes[1].getPixelStride();
		int vRow = planes[2].getRowStride();
		int vPix = planes[2].getPixelStride();
		for (int y = 0; y < height; y++) {
			int src = y * width * 4;
			int dst = y * yRow;
			for (int x = 0; x < width; x++) {
				int r = rgba[src] & 255;
				int g = rgba[src + 1] & 255;
				int b = rgba[src + 2] & 255;
				yb.put(dst + x * yPix, (byte) clamp(((66 * r + 129 * g + 25 * b + 128) >> 8) + 16));
				src += 4;
			}
		}
		for (int y = 0; y < height / 2; y++) {
			for (int x = 0; x < width / 2; x++) {
				int i = ((y * 2) * width + x * 2) * 4;
				int r = rgba[i] & 255;
				int g = rgba[i + 1] & 255;
				int b = rgba[i + 2] & 255;
				ub.put(y * uRow + x * uPix, (byte) clamp(((-38 * r - 74 * g + 112 * b + 128) >> 8) + 128));
				vb.put(y * vRow + x * vPix, (byte) clamp(((112 * r - 94 * g - 18 * b + 128) >> 8) + 128));
			}
		}
	}

	/** Fallback when the codec offers no Image: planar I420. */
	private void fillI420(ByteBuffer buf, byte[] rgba) {
		buf.clear();
		int ySize = width * height;
		int cSize = ySize / 4;
		for (int i = 0, p = 0; i < ySize; i++, p += 4) {
			int r = rgba[p] & 255;
			int g = rgba[p + 1] & 255;
			int b = rgba[p + 2] & 255;
			buf.put(i, (byte) clamp(((66 * r + 129 * g + 25 * b + 128) >> 8) + 16));
		}
		for (int y = 0; y < height / 2; y++) {
			for (int x = 0; x < width / 2; x++) {
				int i = ((y * 2) * width + x * 2) * 4;
				int r = rgba[i] & 255;
				int g = rgba[i + 1] & 255;
				int b = rgba[i + 2] & 255;
				int c = y * (width / 2) + x;
				buf.put(ySize + c, (byte) clamp(((-38 * r - 74 * g + 112 * b + 128) >> 8) + 128));
				buf.put(ySize + cSize + c, (byte) clamp(((112 * r - 94 * g - 18 * b + 128) >> 8) + 128));
			}
		}
	}

	// --- Audio ------------------------------------------------------------------

	/** Encodes `durationUs` of a 16-bit PCM WAV (looped if short) to AAC in memory. */
	private void encodeAudio(String wavPath, long durationUs) throws Exception {
		short[] pcm;
		int rate;
		int channels;
		try (RandomAccessFile f = new RandomAccessFile(wavPath, "r")) {
			byte[] all = new byte[(int) f.length()];
			f.readFully(all);
			ByteBuffer bb = ByteBuffer.wrap(all).order(ByteOrder.LITTLE_ENDIAN);
			int pos = 12;
			rate = 44100;
			channels = 1;
			int bits = 16;
			int dataStart = -1;
			int dataLen = 0;
			while (pos + 8 <= all.length) {
				String id = new String(all, pos, 4, "US-ASCII");
				int len = bb.getInt(pos + 4);
				if (id.equals("fmt ")) {
					channels = bb.getShort(pos + 10);
					rate = bb.getInt(pos + 12);
					bits = bb.getShort(pos + 22);
				} else if (id.equals("data")) {
					dataStart = pos + 8;
					dataLen = Math.min(len, all.length - dataStart);
					break;
				}
				pos += 8 + len + (len & 1);
			}
			if (dataStart < 0 || bits != 16) {
				throw new IllegalArgumentException("need 16-bit PCM WAV");
			}
			pcm = new short[dataLen / 2];
			bb.position(dataStart);
			bb.asShortBuffer().get(pcm, 0, pcm.length);
		}
		long totalFrames = durationUs * rate / 1_000_000L;
		int fileFrames = pcm.length / channels;
		long fadeOut = Math.min(totalFrames, (long) (rate * 1.2));
		MediaFormat af = MediaFormat.createAudioFormat(AUDIO_MIME, rate, channels);
		af.setInteger(MediaFormat.KEY_AAC_PROFILE, MediaCodecInfo.CodecProfileLevel.AACObjectLC);
		af.setInteger(MediaFormat.KEY_BIT_RATE, 128_000);
		af.setInteger(MediaFormat.KEY_MAX_INPUT_SIZE, 16384);
		MediaCodec enc = MediaCodec.createEncoderByType(AUDIO_MIME);
		enc.configure(af, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE);
		enc.start();
		MediaCodec.BufferInfo ai = new MediaCodec.BufferInfo();
		long fed = 0;
		boolean inputDone = false;
		boolean outputDone = false;
		int guard = 0;
		try {
			while (!outputDone && guard++ < 200_000) {
				if (!inputDone) {
					int in = enc.dequeueInputBuffer(TIMEOUT_US);
					if (in >= 0) {
						ByteBuffer b = enc.getInputBuffer(in);
						b.clear();
						b.order(ByteOrder.LITTLE_ENDIAN);
						int maxFrames = Math.min(b.remaining() / (2 * channels), 1024);
						int n = (int) Math.min(maxFrames, totalFrames - fed);
						long pts = fed * 1_000_000L / rate;
						if (n <= 0) {
							enc.queueInputBuffer(in, 0, 0, pts, MediaCodec.BUFFER_FLAG_END_OF_STREAM);
							inputDone = true;
						} else {
							for (int k = 0; k < n; k++) {
								long frame = fed + k;
								float gain = 1.0f;
								long left = totalFrames - frame;
								if (left < fadeOut) {
									gain = (float) left / (float) fadeOut;
								}
								int src = (int) (frame % fileFrames) * channels;
								for (int c = 0; c < channels; c++) {
									b.putShort((short) (pcm[src + c] * gain));
								}
							}
							enc.queueInputBuffer(in, 0, n * 2 * channels, pts, 0);
							fed += n;
						}
					}
				}
				int out = enc.dequeueOutputBuffer(ai, TIMEOUT_US);
				if (out == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
					audioFormat = enc.getOutputFormat();
				} else if (out >= 0) {
					ByteBuffer o = enc.getOutputBuffer(out);
					if ((ai.flags & MediaCodec.BUFFER_FLAG_CODEC_CONFIG) == 0 && ai.size > 0 && o != null) {
						byte[] d = new byte[ai.size];
						o.position(ai.offset);
						o.get(d);
						MediaCodec.BufferInfo copy = new MediaCodec.BufferInfo();
						copy.set(0, ai.size, ai.presentationTimeUs, ai.flags & ~MediaCodec.BUFFER_FLAG_END_OF_STREAM);
						audioData.add(d);
						audioInfo.add(copy);
					}
					enc.releaseOutputBuffer(out, false);
					if ((ai.flags & MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) {
						outputDone = true;
					}
				}
			}
		} finally {
			enc.stop();
			enc.release();
		}
	}

	private void writeAudio() {
		if (audioTrack < 0) {
			return;
		}
		for (int i = 0; i < audioData.size(); i++) {
			muxer.writeSampleData(audioTrack, ByteBuffer.wrap(audioData.get(i)), audioInfo.get(i));
		}
		audioData.clear();
		audioInfo.clear();
	}

	private void release() {
		try {
			if (video != null) {
				video.stop();
			}
		} catch (Exception ignored) {
		}
		try {
			if (video != null) {
				video.release();
			}
		} catch (Exception ignored) {
		}
		try {
			if (muxer != null) {
				muxer.release();
			}
		} catch (Exception ignored) {
		}
		video = null;
		muxer = null;
		muxerStarted = false;
	}
}
