from nsepython import *
import pandas as pd
import json
import sys
import traceback

try:
    symbol = sys.argv[1] if len(sys.argv) > 1 else "^NSEI"

    # Yahoo → NSE index name mapping
    index_map = {
        "^NSEI": "NIFTY 50",
        "^NSEBANK": "NIFTY BANK",
        "^BSESN": "NIFTY 50",
        "^CNXIT": "NIFTY IT"
    }

    def get_movers():
        try:
            index_name = index_map.get(symbol, "NIFTY 50")
            
            # Use nsepython's built-in function with proper error handling
            url = f"https://www.nseindia.com/api/equity-stockIndices?index={index_name.replace(' ', '%20')}"
            
            stocks = []
            
            # nsefetch handles headers and cookies automatically
            data = nsefetch(url)
            
            if not data or "data" not in data:
                print(json.dumps({
                    "gainers": [],
                    "losers": []
                }))
                return
            
            items = data["data"]
            
            for d in items:
                # Skip the index itself
                if d.get("symbol") == index_name:
                    continue
                
                stocks.append({
                    "symbol": d.get("symbol"),
                    "lastPrice": d.get("lastPrice", 0),
                    "pChange": d.get("pChange", 0)
                })
            
            if not stocks:
                print(json.dumps({
                    "gainers": [],
                    "losers": []
                }))
                return
            
            df = pd.DataFrame(stocks)
            
            # Separate gainers and losers
            gainers_df = df[df["pChange"] > 0]
            losers_df = df[df["pChange"] < 0]
            
            # Sort and get top 5
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
        
        except Exception as e:
            # Return empty data on any error
            print(json.dumps({
                "gainers": [],
                "losers": []
            }))
            sys.stderr.write(f"Error in get_movers: {str(e)}\n")
    
    get_movers()

except Exception as e:
    # Catch any top-level errors
    print(json.dumps({
        "gainers": [],
        "losers": []
    }))
    sys.stderr.write(f"Top-level error: {str(e)}\n")
    sys.stderr.write(traceback.format_exc())