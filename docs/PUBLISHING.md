# Publishing checklist

## Web

- Install the matching Godot export templates.
- Open the Web preset in Project > Export.
- Target browsers need WebAssembly and WebGL 2.0 support.
- Export `build/web/index.html` and test it in a browser.
- Upload every exported file to a static host that supports HTTPS.
- Check desktop, phone, portrait, and landscape sizes.
- Try sound after the first tap. Browsers block sound before that.

## Google Play and App Store

- Make a signed release build with the right store export preset.
- Prepare the store name, icon, screenshots, age rating, and support contact.
- Create developer accounts and app records in each store.
- Check store rules, age ratings, privacy details, and device support.
- Test signed builds on real Android and Apple devices.

## Ads

- Create an AdMob account before adding Google ad support.
- Use test ad IDs during development. Never test with live ads.
- Prepare a public privacy policy and add its link in `game/config/app_links.gd`.
- Decide whether children may play. Follow the child privacy and ad rules
  for every country where the game is offered.
- Use child-safe ad settings and age ratings when they apply.
- Keep rewarded ads optional. Explain the reward before each ad starts.
- Review the current Google Play, Apple, and ad network rules before release.

Website, privacy, and support links are empty in the app config for now.
The ad provider in this build is a local mock. It sends no network requests.
