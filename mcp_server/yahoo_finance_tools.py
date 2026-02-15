import requests
from datetime import datetime
from typing import Dict, Any, List
from symbol_mapper import get_best_symbol, get_company_display_name

def get_real_time_price(symbol: str) -> Dict[str, Any]:
    """Get real-time stock price using Yahoo Finance API"""
    try:
        # Get all Indian stock symbols from CSV
        from symbol_mapper import _matcher
        indian_symbols = set(_matcher.symbol_to_name.keys())
        
        # Determine if it's Indian stock or US stock
        if symbol in indian_symbols:
            yahoo_symbol = f"{symbol}.NS"
        else:
            yahoo_symbol = symbol  # US stocks don't need suffix
            
        url = f"https://query2.finance.yahoo.com/v8/finance/chart/{yahoo_symbol}?interval=1d&range=1d"
        
        headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
        }
        
        response = requests.get(url, headers=headers, timeout=10)
        
        if response.status_code != 200:
            return {"error": f"API returned status {response.status_code}"}
            
        data = response.json()
        
        if not data.get('chart', {}).get('result'):
            return {"error": f"No data found for {symbol}"}
        
        result = data['chart']['result'][0]
        meta = result.get('meta', {})
        
        current_price = meta.get('regularMarketPrice', 0)
        prev_close = meta.get('previousClose', 0)
        
        if current_price == 0:
            return {"error": f"No price data for {symbol}"}
        
        change = current_price - prev_close
        change_percent = (change / prev_close * 100) if prev_close else 0
        
        return {
            "symbol": symbol,
            "company_name": get_company_display_name(symbol),
            "current_price": round(current_price, 2),
            "previous_close": round(prev_close, 2),
            "change": round(change, 2),
            "change_percent": round(change_percent, 2),
            "volume": meta.get('regularMarketVolume', 0),
            "high": round(meta.get('regularMarketDayHigh', 0), 2),
            "low": round(meta.get('regularMarketDayLow', 0), 2),
            "market_cap": meta.get('marketCap'),
            "timestamp": datetime.now().isoformat()
        }
    except Exception as e:
        return {"error": str(e)}

def get_trending_stocks(period: str = "today", limit: int = 10) -> List[Dict[str, Any]]:
    """Get most volatile stocks from top NSE stocks"""
    # Use top liquid stocks for faster response
    top_stocks = ["RELIANCE", "TCS", "HDFCBANK", "INFY", "ICICIBANK", "KOTAKBANK", 
                  "HINDUNILVR", "SBIN", "BHARTIARTL", "ITC", "ASIANPAINT", "AXISBANK",
                  "MARUTI", "BAJFINANCE", "LT", "WIPRO", "ULTRACEMCO", "TITAN", 
                  "NESTLEIND", "POWERGRID", "ADANIPORTS", "TATAMOTORS", "SUNPHARMA",
                  "ONGC", "NTPC", "JSWSTEEL", "TECHM", "HCLTECH", "INDUSINDBK", "DRREDDY"]
    
    # Determine range based on period
    if period == "weekly":
        range_param = "5d"  # 5 trading days = 1 week
    else:
        range_param = "1d"  # today
    
    trending_data = []
    
    for symbol in top_stocks:
        try:
            yahoo_symbol = f"{symbol}.NS"
            url = f"https://query1.finance.yahoo.com/v8/finance/chart/{yahoo_symbol}?range={range_param}&interval=1d"
            
            headers = {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
            }
            
            response = requests.get(url, headers=headers, timeout=2)
            if response.status_code == 200:
                data = response.json()
                if data.get('chart', {}).get('result'):
                    result = data['chart']['result'][0]
                    meta = result.get('meta', {})
                    
                    current = meta.get('regularMarketPrice', 0)
                    
                    if period == "weekly":
                        # Get historical prices for weekly calculation
                        timestamps = result.get('timestamp', [])
                        quotes = result.get('indicators', {}).get('quote', [{}])[0]
                        closes = quotes.get('close', [])
                        
                        if closes and len(closes) > 0:
                            # Filter out None values
                            valid_closes = [c for c in closes if c is not None]
                            if len(valid_closes) >= 2:
                                week_start = valid_closes[0]
                                week_end = valid_closes[-1]
                                change_pct = ((week_end - week_start) / week_start * 100)
                                
                                trending_data.append({
                                    "symbol": symbol,
                                    "company_name": get_company_display_name(symbol),
                                    "current_price": round(week_end, 2),
                                    "week_start_price": round(week_start, 2),
                                    "change_percent": round(change_pct, 2),
                                    "period": "weekly"
                                })
                    else:
                        # Daily calculation
                        prev = meta.get('previousClose', 0)
                        if current > 0 and prev > 0:
                            change_pct = ((current - prev) / prev * 100)
                            trending_data.append({
                                "symbol": symbol,
                                "company_name": get_company_display_name(symbol),
                                "current_price": round(current, 2),
                                "change_percent": round(change_pct, 2),
                                "period": "daily"
                            })
        except Exception as e:
            continue
    
    # Sort by absolute change percentage (most volatile first)
    trending_data.sort(key=lambda x: abs(x.get('change_percent', 0)), reverse=True)
    return trending_data[:limit]

def get_top_gainers(period: str = "today", limit: int = 10) -> List[Dict[str, Any]]:
    """Get top gainers using trending stocks data"""
    trending = get_trending_stocks(period, 30)  # Get more stocks to filter
    gainers = [stock for stock in trending if stock.get('change_percent', 0) > 0]
    gainers.sort(key=lambda x: x['change_percent'], reverse=True)  # Sort by highest gain
    return gainers[:limit]

def get_top_losers(period: str = "today", limit: int = 10) -> List[Dict[str, Any]]:
    """Get top losers using trending stocks data"""
    trending = get_trending_stocks(period, 30)  # Get more stocks to filter
    losers = [stock for stock in trending if stock.get('change_percent', 0) < 0]
    losers.sort(key=lambda x: x['change_percent'])  # Sort by lowest (most negative)
    return losers[:limit]

def get_market_summary() -> Dict[str, Any]:
    """Get market summary using Yahoo Finance API"""
    try:
        url = "https://query2.finance.yahoo.com/v8/finance/chart/^NSEI?interval=1d&range=1d"
        headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
        }
        response = requests.get(url, headers=headers, timeout=10)
        
        if response.status_code != 200:
            return {"error": f"API returned status {response.status_code}"}
            
        data = response.json()
        
        if data.get('chart', {}).get('result'):
            result = data['chart']['result'][0]
            meta = result.get('meta', {})
            
            current_price = meta.get('regularMarketPrice', 0)
            prev_close = meta.get('previousClose', 0)
            
            if current_price > 0:
                change = current_price - prev_close
                change_percent = (change / prev_close * 100) if prev_close else 0
                
                return {
                    "nifty_50": {
                        "current": round(current_price, 2),
                        "change": round(change, 2),
                        "change_percent": round(change_percent, 2)
                    },
                    "timestamp": datetime.now().isoformat(),
                    "market_status": "Open" if datetime.now().hour in range(9, 16) else "Closed"
                }
        
        return {"error": "No NIFTY data"}
    except Exception as e:
        return {"error": str(e)}

def search_and_get_price(company_query: str) -> Dict[str, Any]:
    """Search for company and get its real-time price"""
    symbol = get_best_symbol(company_query)
    if symbol:
        return get_real_time_price(symbol)
    return {"error": f"Company '{company_query}' not found"}