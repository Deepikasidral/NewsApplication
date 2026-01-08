from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
import requests
import os
from dotenv import load_dotenv
from openai import AzureOpenAI
from datetime import datetime
import json
import asyncio
from typing import Optional, Dict, Any, List
import uvicorn

# MCP SDK imports
try:
    from mcp.server import Server
    from mcp.types import Tool, TextContent, Resource
    MCP_AVAILABLE = True
except ImportError:
    MCP_AVAILABLE = False
    print("⚠️  MCP SDK not available. Install with: pip install mcp")

# Load environment variables
load_dotenv()

app = FastAPI(
    title="AI Overview MCP Server",
    description="Financial AI Overview using Model Context Protocol (MCP)",
    version="1.0.0"
)

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

AZURE_OPENAI_ENDPOINT = os.getenv('AZURE_OPENAI_ENDPOINT', '')
AZURE_OPENAI_KEY = os.getenv('AZURE_OPENAI_KEY', '')
AZURE_DEPLOYMENT = os.getenv('AZURE_DEPLOYMENT', 'gpt-4o-mini')
AZURE_OPENAI_API_VERSION = os.getenv('AZURE_OPENAI_API_VERSION', '2024-02-01')
FINEDGE_API_TOKEN = os.getenv('FINEDGE_API_TOKEN', '')

# Initialize Azure OpenAI client
try:
    azure_client = AzureOpenAI(
        azure_endpoint=AZURE_OPENAI_ENDPOINT,
        api_key=AZURE_OPENAI_KEY,
        api_version=AZURE_OPENAI_API_VERSION
    )
    print("✓ Azure OpenAI client initialized successfully")
except Exception as e:
    print(f"✗ Error initializing Azure OpenAI client: {e}")
    azure_client = None

# Initialize MCP Server
if MCP_AVAILABLE:
    mcp_server = Server("financial-ai-overview-server")
    print("✓ MCP Server initialized")
else:
    mcp_server = None

# ============================================================================
# MCP SERVER IMPLEMENTATION
# ============================================================================

if MCP_AVAILABLE:
    
    @mcp_server.list_resources()
    async def list_resources() -> list[Resource]:
        """List available financial data resources via MCP"""
        return [
            Resource(
                uri="finedge://income-statement",
                name="Income Statement",
                description="Company income statement with revenue, EBITDA, EBIT, net profit, EPS",
                mimeType="application/json"
            ),
            Resource(
                uri="finedge://balance-sheet",
                name="Balance Sheet",
                description="Company balance sheet with assets, liabilities, debt, cash, equity",
                mimeType="application/json"
            ),
            Resource(
                uri="finedge://cash-flow",
                name="Cash Flow Statement",
                description="Company cash flow with operating, investing, financing, and free cash flow",
                mimeType="application/json"
            )
        ]
    
    @mcp_server.read_resource()
    async def read_resource(uri: str) -> str:
        """Read financial data resource via MCP protocol"""
        # Parse URI: finedge://income-statement/TCS
        parts = uri.split('/')
        if len(parts) < 4:
            return json.dumps({"error": "Invalid URI format. Expected: finedge://resource-type/SYMBOL"})
        
        resource_type = parts[2]
        symbol = parts[3]
        
        print(f"[MCP] Reading resource: {uri}")
        
        statement_map = {
            "income-statement": "pl",
            "balance-sheet": "bs",
            "cash-flow": "cf"
        }
        
        statement_code = statement_map.get(resource_type)
        if not statement_code:
            return json.dumps({"error": f"Unknown resource type: {resource_type}"})
        
        # Fetch from Finedge API
        url = f"https://data.finedgeapi.com/api/v1/financials/{symbol}"
        params = {
            'statement_type': 's',
            'statement_code': statement_code,
            'period': 'annual',
            'token': FINEDGE_API_TOKEN
        }
        
        try:
            response = requests.get(url, params=params, timeout=10)
            if response.status_code == 200:
                data = response.json()
                return json.dumps(data, indent=2)
        except Exception as e:
            return json.dumps({"error": str(e)})
        
        return json.dumps({"error": "Failed to fetch resource"})
    
    @mcp_server.list_tools()
    async def list_tools() -> list[Tool]:
        """List available MCP tools"""
        return [
            Tool(
                name="fetch_company_financials",
                description="Fetch comprehensive financial data (income statement, balance sheet, cash flow) for a company using Finedge API",
                inputSchema={
                    "type": "object",
                    "properties": {
                        "symbol": {
                            "type": "string",
                            "description": "Stock symbol (e.g., TCS, INFY, RELIANCE)"
                        },
                        "company_name": {
                            "type": "string",
                            "description": "Company name for context"
                        }
                    },
                    "required": ["symbol"]
                }
            ),
            Tool(
                name="generate_investment_overview",
                description="Generate AI-powered investment overview using Groq LLM with financial data from MCP resources",
                inputSchema={
                    "type": "object",
                    "properties": {
                        "symbol": {
                            "type": "string",
                            "description": "Stock symbol"
                        },
                        "company_name": {
                            "type": "string",
                            "description": "Company name"
                        },
                        "financial_data": {
                            "type": "object",
                            "description": "Structured financial data from MCP resources"
                        }
                    },
                    "required": ["symbol", "company_name", "financial_data"]
                }
            ),
            Tool(
                name="analyze_financial_health",
                description="Analyze company financial health using MCP resource data and provide detailed metrics",
                inputSchema={
                    "type": "object",
                    "properties": {
                        "symbol": {
                            "type": "string",
                            "description": "Stock symbol"
                        }
                    },
                    "required": ["symbol"]
                }
            )
        ]
    
    @mcp_server.call_tool()
    async def call_tool(name: str, arguments: dict) -> list[TextContent]:
        """Execute MCP tool calls"""
        
        print(f"\n[MCP TOOL CALL] {name}")
        print(f"Arguments: {json.dumps(arguments, indent=2)}")
        
        if name == "fetch_company_financials":
            symbol = arguments.get("symbol")
            company_name = arguments.get("company_name", symbol)
            
            financials = await fetch_all_financials_async(symbol)
            
            result = {
                "tool": "fetch_company_financials",
                "company_name": company_name,
                "symbol": symbol,
                "financial_data": financials,
                "mcp_resources_used": [
                    f"finedge://income-statement/{symbol}",
                    f"finedge://balance-sheet/{symbol}",
                    f"finedge://cash-flow/{symbol}"
                ]
            }
            
            return [TextContent(
                type="text",
                text=json.dumps(result, indent=2)
            )]
        
        elif name == "generate_investment_overview":
            symbol = arguments.get("symbol")
            company_name = arguments.get("company_name")
            financial_data = arguments.get("financial_data")
            
            # Format financial data for LLM
            formatted_context = format_financial_context_for_llm(financial_data, company_name, symbol)
            
            # Generate overview using Groq
            overview = await generate_llm_overview_async(company_name, symbol, formatted_context)
            
            result = {
                "tool": "generate_investment_overview",
                "company_name": company_name,
                "symbol": symbol,
                "overview": overview,
                "llm_model": AZURE_DEPLOYMENT,
                "mcp_protocol": "v1.1"
            }
            
            return [TextContent(
                type="text",
                text=json.dumps(result, indent=2)
            )]
        
        elif name == "analyze_financial_health":
            symbol = arguments.get("symbol")
            
            financials = await fetch_all_financials_async(symbol)
            
            # Calculate financial ratios
            analysis = calculate_financial_ratios(financials)
            
            result = {
                "tool": "analyze_financial_health",
                "symbol": symbol,
                "analysis": analysis,
                "mcp_resources_used": [
                    f"finedge://income-statement/{symbol}",
                    f"finedge://balance-sheet/{symbol}",
                    f"finedge://cash-flow/{symbol}"
                ]
            }
            
            return [TextContent(
                type="text",
                text=json.dumps(result, indent=2)
            )]
        
        return [TextContent(
            type="text",
            text=json.dumps({"error": f"Unknown tool: {name}"})
        )]

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

async def fetch_all_financials_async(symbol: str) -> dict:
    """Async wrapper for fetching financials"""
    return fetch_comprehensive_financials(symbol)

def fetch_comprehensive_financials(symbol):
    """Fetch all financial statements from Finedge API"""
    financials = {
        'income_statement': {},
        'balance_sheet': {},
        'cash_flow': {}
    }
    
    url = f"https://data.finedgeapi.com/api/v1/financials/{symbol}"
    
    try:
        # Fetch Income Statement (Profit & Loss)
        print(f"[MCP Resource] Accessing: finedge://income-statement/{symbol}")
        params_pl = {
            'statement_type': 's',
            'statement_code': 'pl',
            'period': 'annual',
            'token': FINEDGE_API_TOKEN
        }
        response_pl = requests.get(url, params=params_pl, timeout=10)
        if response_pl.status_code == 200:
            data = response_pl.json()
            if data and 'financials' in data and data['financials']:
                latest = data['financials'][0]
                
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
                print(f"✓ MCP Resource loaded: income_statement")
        
        # Fetch Balance Sheet
        print(f"[MCP Resource] Accessing: finedge://balance-sheet/{symbol}")
        params_bs = {
            'statement_type': 's',
            'statement_code': 'bs',
            'period': 'annual',
            'token': FINEDGE_API_TOKEN
        }
        response_bs = requests.get(url, params=params_bs, timeout=10)
        if response_bs.status_code == 200:
            data = response_bs.json()
            if data and 'financials' in data and data['financials']:
                latest = data['financials'][0]
                
                financials['balance_sheet'] = {
                    'total_assets': latest.get('totalAssets'),
                    'total_liabilities': latest.get('totalLiabilities'),
                    'total_debt': latest.get('totalDebt') or latest.get('borrowings'),
                    'cash_equivalents': latest.get('cashAndCashEquivalents'),
                    'equity': latest.get('totalEquity') or latest.get('shareholdersEquity')
                }
                print(f"✓ MCP Resource loaded: balance_sheet")
        
        # Fetch Cash Flow Statement
        print(f"[MCP Resource] Accessing: finedge://cash-flow/{symbol}")
        params_cf = {
            'statement_type': 's',
            'statement_code': 'cf',
            'period': 'annual',
            'token': FINEDGE_API_TOKEN
        }
        response_cf = requests.get(url, params=params_cf, timeout=10)
        if response_cf.status_code == 200:
            data = response_cf.json()
            if data and 'financials' in data and data['financials']:
                latest = data['financials'][0]
                
                operating_cf = latest.get('operatingActivities') or latest.get('cashFlowFromOperatingActivities')
                investing_cf = latest.get('investingActivities') or latest.get('cashFlowFromInvestingActivities')
                financing_cf = latest.get('financingActivities') or latest.get('cashFlowFromFinancingActivities')
                
                free_cf = None
                if operating_cf and investing_cf:
                    free_cf = float(operating_cf) + float(investing_cf)
                
                financials['cash_flow'] = {
                    'operating_cf': operating_cf,
                    'investing_cf': investing_cf,
                    'financing_cf': financing_cf,
                    'free_cf': free_cf
                }
                print(f"✓ MCP Resource loaded: cash_flow")
                
    except Exception as e:
        print(f"Error fetching comprehensive financials: {e}")
    
    return financials

def format_financial_context_for_llm(financial_data: dict, company_name: str, symbol: str) -> str:
    """Format financial data as MCP context for LLM"""
    
    def format_value(val, unit='Cr'):
        if val is None:
            return 'N/A'
        try:
            num = float(val) / 10000000
            return f"₹{num:,.2f} {unit}"
        except:
            return str(val)
    
    income = financial_data.get('income_statement', {})
    balance = financial_data.get('balance_sheet', {})
    cashflow = financial_data.get('cash_flow', {})
    
    context = f"""
MCP FINANCIAL CONTEXT for {company_name} ({symbol}):

[MCP RESOURCE: finedge://income-statement/{symbol}]
Revenue: {format_value(income.get('revenue'))}
EBITDA: {format_value(income.get('ebitda'))}
EBIT: {format_value(income.get('ebit'))}
Net Profit: {format_value(income.get('net_profit'))}
EPS: ₹{income.get('eps', 'N/A')}

[MCP RESOURCE: finedge://balance-sheet/{symbol}]
Total Assets: {format_value(balance.get('total_assets'))}
Total Liabilities: {format_value(balance.get('total_liabilities'))}
Total Debt: {format_value(balance.get('total_debt'))}
Cash & Equivalents: {format_value(balance.get('cash_equivalents'))}
Shareholders' Equity: {format_value(balance.get('equity'))}

[MCP RESOURCE: finedge://cash-flow/{symbol}]
Operating Cash Flow: {format_value(cashflow.get('operating_cf'))}
Investing Cash Flow: {format_value(cashflow.get('investing_cf'))}
Financing Cash Flow: {format_value(cashflow.get('financing_cf'))}
Free Cash Flow: {format_value(cashflow.get('free_cf'))}
"""
    return context

async def generate_llm_overview_async(company_name: str, symbol: str, financial_context: str) -> str:
    """Async wrapper for LLM generation"""
    return generate_llm_overview(company_name, symbol, financial_context)

def generate_llm_overview(company_name: str, symbol: str, financial_context: str) -> str:
    """Generate investment overview using Azure OpenAI with MCP context"""
    
    if not azure_client:
        return "Error: Azure OpenAI client not initialized"
    
    prompt = f"""
You are an AI financial analyst analyzing company data from MCP resources.

{financial_context}

Based ONLY on the exact financial data above, provide a BRIEF investment insight (2-3 lines maximum):

1. State if the company outlook is BULLISH (positive) or BEARISH (negative)
2. Give 1-2 key reasons using EXACT numbers from the data
3. Mention ONE critical metric investors should watch

Format: Start with "BULLISH" or "BEARISH" verdict, then explain concisely. Be direct and data-driven.
"""
    
    try:
        response = azure_client.chat.completions.create(
            model=AZURE_DEPLOYMENT,
            messages=[
                {
                    "role": "system",
                    "content": "You are a senior financial analyst. Provide SHORT, direct bearish/bullish verdicts with key numbers. Maximum 3 lines."
                },
                {
                    "role": "user",
                    "content": prompt
                }
            ],
            temperature=0.5,
            max_tokens=150
        )
        
        overview = response.choices[0].message.content
        overview = overview.replace('*', '').replace('•', '').replace('- ', '').strip()
        return overview
        
    except Exception as e:
        return f"Error generating overview: {str(e)}"

def calculate_financial_ratios(financials: dict) -> dict:
    """Calculate key financial ratios from MCP resource data"""
    income = financials.get('income_statement', {})
    balance = financials.get('balance_sheet', {})
    cashflow = financials.get('cash_flow', {})
    
    ratios = {}
    
    try:
        # Debt to Equity
        if balance.get('total_debt') and balance.get('equity'):
            ratios['debt_to_equity'] = float(balance['total_debt']) / float(balance['equity'])
        
        # Current Ratio approximation
        if balance.get('total_assets') and balance.get('total_liabilities'):
            ratios['asset_to_liability'] = float(balance['total_assets']) / float(balance['total_liabilities'])
        
        # Profit Margin
        if income.get('net_profit') and income.get('revenue'):
            ratios['profit_margin'] = (float(income['net_profit']) / float(income['revenue'])) * 100
        
        # FCF to Revenue
        if cashflow.get('free_cf') and income.get('revenue'):
            ratios['fcf_to_revenue'] = (float(cashflow['free_cf']) / float(income['revenue'])) * 100
            
    except Exception as e:
        print(f"Error calculating ratios: {e}")
    
    return ratios

# ============================================================================
# FASTAPI REST API ENDPOINTS
# ============================================================================

@app.get('/api/ai-overview/{symbol}')
async def get_ai_overview(
    symbol: str,
    company_name: Optional[str] = Query(None)
):
    """REST API endpoint that uses MCP protocol internally"""
    try:
        if company_name is None:
            company_name = symbol
        
        print(f"\n{'='*60}")
        print(f"🚀 MCP Financial Analysis Pipeline")
        print(f"Protocol: Model Context Protocol (MCP) v1.1")
        print(f"Company: {company_name} ({symbol})")
        print(f"{'='*60}\n")
        
        if not MCP_AVAILABLE:
            print("⚠️  MCP SDK not available, using fallback mode")
        
        # MCP Tool Call: fetch_company_financials
        print("[MCP TOOL CALL] fetch_company_financials")
        financials = fetch_comprehensive_financials(symbol)
        
        # MCP Tool Call: generate_investment_overview
        print("\n[MCP TOOL CALL] generate_investment_overview")
        formatted_context = format_financial_context_for_llm(financials, company_name, symbol)
        print("🤖 Feeding MCP context to Azure OpenAI LLM...")
        
        ai_overview = generate_llm_overview(company_name, symbol, formatted_context)
        
        if ai_overview and not ai_overview.startswith("Error"):
            print("✓ AI Overview generated via MCP protocol")
            print(f"{'='*60}\n")
            
            return {
                'success': True,
                'company_name': company_name,
                'symbol': symbol,
                'overview': ai_overview,
                'mcp_metadata': {
                    'protocol': 'MCP v1.1',
                    'resources_accessed': [
                        f"finedge://income-statement/{symbol}",
                        f"finedge://balance-sheet/{symbol}",
                        f"finedge://cash-flow/{symbol}"
                    ],
                    'tools_used': [
                        'fetch_company_financials',
                        'generate_investment_overview'
                    ],
                    'llm_model': AZURE_DEPLOYMENT,
                    'llm_provider': 'Azure OpenAI'
                },
                'financial_data': financials,
                'generated_at': datetime.now().isoformat()
            }
        else:
            raise HTTPException(status_code=500, detail=ai_overview or 'Failed to generate overview')
            
    except HTTPException:
        raise
    except Exception as e:
        print(f"\n✗ Error: {e}\n")
        raise HTTPException(status_code=500, detail=str(e))

@app.get('/mcp/resources')
async def list_mcp_resources():
    """List available MCP resources"""
    if not MCP_AVAILABLE:
        raise HTTPException(status_code=503, detail='MCP SDK not available')
    
    return {
        'protocol': 'MCP v1.1',
        'resources': [
            {
                'uri': 'finedge://income-statement/{symbol}',
                'name': 'Income Statement',
                'description': 'Company income statement data'
            },
            {
                'uri': 'finedge://balance-sheet/{symbol}',
                'name': 'Balance Sheet',
                'description': 'Company balance sheet data'
            },
            {
                'uri': 'finedge://cash-flow/{symbol}',
                'name': 'Cash Flow Statement',
                'description': 'Company cash flow data'
            }
        ]
    }

@app.get('/mcp/tools')
async def list_mcp_tools():
    """List available MCP tools"""
    if not MCP_AVAILABLE:
        raise HTTPException(status_code=503, detail='MCP SDK not available')
    
    return {
        'protocol': 'MCP v1.1',
        'tools': [
            {
                'name': 'fetch_company_financials',
                'description': 'Fetch comprehensive financial data'
            },
            {
                'name': 'generate_investment_overview',
                'description': 'Generate AI-powered investment overview'
            },
            {
                'name': 'analyze_financial_health',
                'description': 'Analyze financial health metrics'
            }
        ]
    }

@app.get('/health')
async def health_check():
    """Health check endpoint"""
    return {
        'status': 'healthy',
        'service': 'AI Overview MCP Server',
        'protocol': 'Model Context Protocol (MCP) v1.1',
        'mcp_available': MCP_AVAILABLE,
        'azure_openai_status': 'initialized' if azure_client else 'failed',
        'finedge_status': 'configured' if FINEDGE_API_TOKEN else 'missing',
        'capabilities': [
            'mcp_resources',
            'mcp_tools',
            'llm_integration',
            'financial_analysis'
        ]
    }

@app.get('/')
async def root():
    """Root endpoint with API documentation"""
    return {
        'message': 'AI Overview MCP Server',
        'version': '1.0.0',
        'protocol': 'MCP v1.1',
        'endpoints': {
            'health': '/health',
            'ai_overview': '/api/ai-overview/{symbol}',
            'mcp_resources': '/mcp/resources',
            'mcp_tools': '/mcp/tools',
            'docs': '/docs'
        }
    }

if __name__ == '__main__':
    print("\n" + "="*60)
    print("🚀 AI Overview MCP Server Starting...")
    print("="*60)
    print(f"MCP SDK: {'✓ Installed' if MCP_AVAILABLE else '✗ Not Available'}")
    print(f"Protocol: Model Context Protocol (MCP) v1.1")
    print(f"LLM: Azure OpenAI ({AZURE_DEPLOYMENT})")
    print(f"Data Source: Finedge API")
    print(f"Azure OpenAI: {'✓ Initialized' if azure_client else '✗ Failed'}")
    print(f"Finedge API: {'✓ Configured' if FINEDGE_API_TOKEN else '✗ Missing'}")
    print("="*60)
    
    if MCP_AVAILABLE:
        print("\n📋 MCP Resources Available:")
        print("  - finedge://income-statement/{symbol}")
        print("  - finedge://balance-sheet/{symbol}")
        print("  - finedge://cash-flow/{symbol}")
        
        print("\n🛠️  MCP Tools Available:")
        print("  - fetch_company_financials")
        print("  - generate_investment_overview")
        print("  - analyze_financial_health")
    
    print("\n" + "="*60 + "\n")
    uvicorn.run(app, host='0.0.0.0', port=5001)
