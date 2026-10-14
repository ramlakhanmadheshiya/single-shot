#!/usr/bin/env python3
"""The in-app products One Clean Shot sells, and a way to create them on Google Play.

  python3 store/play_products.py list                  # print every product and price
  python3 store/play_products.py csv > products.csv    # the same, as CSV
  python3 store/play_products.py create KEY.json       # create them through the API

`create` uses the Google Play Android Developer API (in-app products) with a
service account JSON key (Play Console > Users and permissions: invite the service
account with permission to manage the app's products). It needs:
  python3 -m pip install google-auth requests
Products that already exist are skipped, so it is safe to run again.

Prices are set in Indian rupees; Play converts them for other countries.
The product IDs must match game/autoload/store.gd.
"""
import csv
import json
import sys

PACKAGE = "io.github.ramlakhanmadheshiya.onecleanshot"
CURRENCY = "INR"

# One-time packs (kept forever, restorable).
PACKS = [
    ("complete_pack", "Complete pack", "No ads, every hint free, all orbs and themes, and 5 level keys.", 449),
    ("supporter_pack", "Supporter pack", "No banner ads, and every hint free, always.", 249),
    ("orb_pack", "Orb pack", "Six more orb styles, each with its own trail.", 149),
    ("theme_pack", "Theme pack", "Eleven colour themes, light and dark.", 149),
]

KEY_PRICE = 30          # per key
KEY_BULK = 5            # buying this many or more ...
KEY_DISCOUNT = 0.10     # ... takes 10% off
KEY_MAX = 10
TIP_MIN, TIP_MAX, TIP_STEP = 10, 1000, 10


def products():
    out = []
    for pid, title, desc, price in PACKS:
        out.append({"id": pid, "title": title, "description": desc, "price": price, "kind": "pack"})
    for n in range(1, KEY_MAX + 1):
        price = n * KEY_PRICE * (1 - KEY_DISCOUNT if n >= KEY_BULK else 1)
        out.append({
            "id": f"keys_{n}",
            "title": f"{n} level key" + ("s" if n > 1 else ""),
            "description": "A key opens any locked room for good." if n == 1 else f"{n} keys. Each opens any locked room for good.",
            "price": round(price),
            "kind": "consumable",
        })
    for r in range(TIP_MIN, TIP_MAX + 1, TIP_STEP):
        out.append({
            "id": f"tip_{r}",
            "title": f"Tip ₹{r}",
            "description": "A thank-you to the developer. Opens nothing new.",
            "price": r,
            "kind": "consumable",
        })
    return out


def cmd_list():
    for p in products():
        print(f"{p['id']:16s} ₹{p['price']:<5d} {p['kind']:10s} {p['title']}")
    print(f"\n{len(products())} products")


def cmd_csv():
    w = csv.writer(sys.stdout)
    w.writerow(["product_id", "title", "description", "price_inr", "kind"])
    for p in products():
        w.writerow([p["id"], p["title"], p["description"], p["price"], p["kind"]])


def cmd_create(key_path):
    from google.oauth2 import service_account
    from google.auth.transport.requests import AuthorizedSession

    creds = service_account.Credentials.from_service_account_file(
        key_path, scopes=["https://www.googleapis.com/auth/androidpublisher"])
    session = AuthorizedSession(creds)
    base = f"https://androidpublisher.googleapis.com/androidpublisher/v3/applications/{PACKAGE}/inappproducts"
    existing = set()
    token = None
    while True:
        r = session.get(base, params={"token": token} if token else {})
        r.raise_for_status()
        data = r.json()
        existing |= {p["sku"] for p in data.get("inappproduct", [])}
        token = data.get("tokenPagination", {}).get("nextPageToken")
        if not token:
            break
    made = 0
    for p in products():
        if p["id"] in existing:
            print(f"skip   {p['id']} (exists)")
            continue
        body = {
            "packageName": PACKAGE,
            "sku": p["id"],
            "status": "active",
            "purchaseType": "managedUser",
            "defaultLanguage": "en-US",
            "listings": {"en-US": {"title": p["title"], "description": p["description"]}},
            "defaultPrice": {"priceMicros": str(p["price"] * 1_000_000), "currency": CURRENCY},
        }
        r = session.post(base, params={"autoConvertMissingPrices": "true"}, data=json.dumps(body),
                         headers={"Content-Type": "application/json"})
        if r.ok:
            made += 1
            print(f"create {p['id']} ₹{p['price']}")
        else:
            print(f"FAILED {p['id']}: {r.status_code} {r.text[:300]}")
    print(f"\nCreated {made}, skipped {len(existing & {p['id'] for p in products()})}.")


if __name__ == "__main__":
    if len(sys.argv) < 2 or sys.argv[1] == "list":
        cmd_list()
    elif sys.argv[1] == "csv":
        cmd_csv()
    elif sys.argv[1] == "create" and len(sys.argv) == 3:
        cmd_create(sys.argv[2])
    else:
        print(__doc__)
        sys.exit(1)
