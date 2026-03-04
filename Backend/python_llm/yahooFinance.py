from nsepython import *
import pandas as pd

def get_top_movers():

    print("\n📈 Fetching Top Gainers...")
    gainers = nse_get_top_gainers()

    print("\n📉 Fetching Top Losers...")
    losers = nse_get_top_losers()

    gainers_df = pd.DataFrame(gainers)
    losers_df = pd.DataFrame(losers)

    gainers_df = gainers_df[['symbol','open','lastPrice','pChange']]
    losers_df = losers_df[['symbol','open','lastPrice','pChange']]

    gainers_df.rename(columns={
        'symbol':'Symbol',
        'open':'Open',
        'lastPrice':'LTP',
        'pChange':'%Change'
    }, inplace=True)

    losers_df.rename(columns={
        'symbol':'Symbol',
        'open':'Open',
        'lastPrice':'LTP',
        'pChange':'%Change'
    }, inplace=True)

    gainers_df = gainers_df.sort_values(by="%Change", ascending=False).head(5)
    losers_df = losers_df.sort_values(by="%Change", ascending=True).head(5)

    print("\n🔥 TOP 5 GAINERS TODAY")
    print(gainers_df.to_string(index=False))

    print("\n💀 TOP 5 LOSERS TODAY")
    print(losers_df.to_string(index=False))

    # Optional Excel Export
    gainers_df.to_excel("Top5_Gainers.xlsx", index=False)
    losers_df.to_excel("Top5_Losers.xlsx", index=False)

get_top_movers()