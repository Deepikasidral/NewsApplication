import os
import requests
from datetime import datetime
from typing import Dict, Any, Optional

FINEDGE_API_TOKEN = os.getenv("FINEDGE_API_TOKEN")
FINEDGE_BASE = "https://data.finedgeapi.com/api/v1"

def fetch_income_statement(symbol: str) -> Dict[str, Any]:
    """Fetch income statement data"""
    try:
        response = requests.get(
            f"{FINEDGE_BASE}/income-statement",
            params={"symbol": symbol, "token": FINEDGE_API_TOKEN},
            timeout=10
        )
        return response.json()
    except Exception as e:
        return {"error": str(e)}

def fetch_balance_sheet(symbol: str) -> Dict[str, Any]:
    """Fetch balance sheet data"""
    try:
        response = requests.get(
            f"{FINEDGE_BASE}/balance-sheet",
            params={"symbol": symbol, "token": FINEDGE_API_TOKEN},
            timeout=10
        )
        return response.json()
    except Exception as e:
        return {"error": str(e)}

def fetch_cash_flow(symbol: str) -> Dict[str, Any]:
    """Fetch cash flow statement"""
    try:
        response = requests.get(
            f"{FINEDGE_BASE}/cash-flow",
            params={"symbol": symbol, "token": FINEDGE_API_TOKEN},
            timeout=10
        )
        return response.json()
    except Exception as e:
        return {"error": str(e)}

def fetch_ratios(symbol: str) -> Dict[str, Any]:
    """Fetch financial ratios"""
    try:
        response = requests.get(
            f"{FINEDGE_BASE}/ratios",
            params={"symbol": symbol, "token": FINEDGE_API_TOKEN},
            timeout=10
        )
        return response.json()
    except Exception as e:
        return {"error": str(e)}

def fetch_valuation(symbol: str) -> Dict[str, Any]:
    """Fetch valuation metrics"""
    try:
        response = requests.get(
            f"{FINEDGE_BASE}/valuation",
            params={"symbol": symbol, "token": FINEDGE_API_TOKEN},
            timeout=10
        )
        return response.json()
    except Exception as e:
        return {"error": str(e)}

def fetch_quote(symbol: str) -> Dict[str, Any]:
    """Fetch current stock quote"""
    try:
        response = requests.get(
            f"{FINEDGE_BASE}/quote",
            params={"symbol": symbol, "token": FINEDGE_API_TOKEN},
            timeout=10
        )
        return response.json()
    except Exception as e:
        return {"error": str(e)}

def fetch_comprehensive_analysis(symbol: str) -> Dict[str, Any]:
    """Fetch all financial data for comprehensive analysis using proper Finedge endpoints"""
    financials = {
        'income_statement': {},
        'balance_sheet': {},
        'cash_flow': {},
        'ratios': {},
        'valuation': {},
        'quote': {}
    }
    
    url_base = "https://data.finedgeapi.com/api/v1"
    
    try:
        # Fetch Income Statement (Profit & Loss)
        print(f"🔍 Fetching Income Statement for {symbol}...")
        params_pl = {
            'statement_type': 's',
            'statement_code': 'pl',
            'period': 'annual',
            'token': FINEDGE_API_TOKEN
        }
        response_pl = requests.get(f"{url_base}/financials/{symbol}", params=params_pl, timeout=10)
        print(f"📊 Income Statement API Response: {response_pl.status_code}")
        if response_pl.status_code == 200:
            data = response_pl.json()
            print(f"📈 Income data keys: {list(data.keys()) if data else 'No data'}")
            if data and 'financials' in data and data['financials']:
                latest = data['financials'][0]
                print(f"✅ Found income statement data")
                
                revenue = latest.get('revenueFromOperations') or latest.get('totalRevenue') or latest.get('income')
                pbt = latest.get('profitBeforeTax')
                fin_costs = latest.get('financeCosts')
                depreciation = latest.get('depreciationAndAmortisation')
                net_profit = latest.get('profitLossForPeriod') or latest.get('profitLossForThePeriod')
                eps = latest.get('eps') or latest.get('earningsPerShare')
                
                ebitda = None
                ebit = None
                if pbt and fin_costs and depreciation:
                    ebitda = float(pbt) + float(fin_costs) + float(depreciation)
                    ebit = float(pbt) + float(fin_costs)
                
                financials['income_statement'] = {
                    'revenue': revenue,
                    'ebitda': ebitda,
                    'ebit': ebit,
                    'net_profit': net_profit,
                    'eps': eps
                }
        
        # Fetch Balance Sheet
        params_bs = {
            'statement_type': 's',
            'statement_code': 'bs',
            'token': FINEDGE_API_TOKEN
        }
        response_bs = requests.get(f"{url_base}/basic-financials/{symbol}", params=params_bs, timeout=10)
        if response_bs.status_code == 200:
            data = response_bs.json()
            if data and 'ratios' in data and data['ratios']:
                latest = data['ratios'][0]
                
                financials['balance_sheet'] = {
                    'total_assets': latest.get('totalAssets'),
                    'total_liabilities': latest.get('totalLiabilities'),
                    'total_debt': latest.get('totalDebt'),
                    'cash_equivalents': latest.get('totalCash'),
                    'equity': latest.get('totalEquity')
                }
        
        # Fetch Quote data
        response_quote = requests.get(f"{url_base}/quote", params={'symbol': symbol, 'token': FINEDGE_API_TOKEN}, timeout=10)
        if response_quote.status_code == 200:
            quote_data = response_quote.json()
            if quote_data and symbol in quote_data:
                financials['quote'] = quote_data[symbol]
                
    except Exception as e:
        print(f"Error fetching comprehensive analysis: {e}")
    
    return {
        "symbol": symbol,
        **financials,
        "fetched_at": datetime.now().isoformat()
    }