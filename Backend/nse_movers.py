from nsepython import *
import pandas as pd
import json
import sys

symbol = sys.argv[1] if len(sys.argv) > 1 else "^NSEI"

# Yahoo → NSE index name mapping
index_map = {
    "^NSEI": "NIFTY 50",
    "^NSEBANK": "NIFTY BANK",
    "^BSESN": "NIFTY 50",   # fallback (NSE has no sensex)
    "^CNXIT": "NIFTY IT"
}

def get_movers():

    index_name = index_map.get(symbol, "NIFTY 50")

    url = f"https://www.nseindia.com/api/equity-stockIndices?index={index_name.replace(' ', '%20')}"

    

    stocks = []

    data = nsefetch(url)

    if not data or "data" not in data:
        print(json.dumps({
            "gainers": [],
            "losers": []
        }))
        sys.exit(0)

    items = data["data"]

    for d in items:

        if d.get("symbol") == index_name:
            continue

        stocks.append({
            "symbol": d.get("symbol"),
            "lastPrice": d.get("lastPrice", 0),
            "pChange": d.get("pChange", 0)
        })

    df = pd.DataFrame(stocks)

    if df.empty:
        print(json.dumps({
            "gainers": [],
            "losers": []
        }))
        return

   # Separate gainers and losers first
    gainers_df = df[df["pChange"] > 0]
    losers_df = df[df["pChange"] < 0]

    # Sort them
    gainers = gainers_df.sort_values(
        by="pChange",
        ascending=False
    ).head(5)

    losers = losers_df.sort_values(
        by="pChange",
        ascending=True
    ).head(5)

    print(json.dumps({
        "gainers": gainers.to_dict(orient="records"),
        "losers": losers.to_dict(orient="records")
    }))

get_movers()