import json
from openai import OpenAI
from datetime import datetime
from pytz import timezone

from mcp_server.config import OPENAI_API_KEY
from mcp_server.tools import (
    search_news,
    get_latest_news,

    get_news_by_sentiment,
    get_news_by_impact,
    finedge_company_tool,
    get_market_news_by_date,
    finedge_full_analysis_tool,
)

# ============================
# TIME & MEMORY
# ============================
IST = timezone("Asia/Kolkata")
today = datetime.now(IST).strftime("%B %d, %Y")
CHAT_HISTORY = []

# ============================
# 🔐 FINAL ANSWER PROMPT
# ============================
SYSTEM_FINAL_PROMPT = f"""
You are a financial assistant.

IMPORTANT CONTEXT:
- Today's date is {today} (IST).
- Never invent prices, returns, or numerical performance.

CORE BEHAVIOR:

1. WHEN the "Information" section CONTAINS meaningful data:
   - Use ONLY that information.
   - Do NOT invent price or percentage-based performance.
   - You MAY reinterpret the user's wording to match the data provided.

   Specifically:
   - If the user asks about "top performing stocks"
     AND the information contains news sentiment, impact, or headlines
     BUT NOT price data,
     THEN:
       → Interpret "top performing" as
         "stocks showing strong positive news momentum".
       → Clearly base the answer on news sentiment and impact.
       → Do NOT state that data is missing.
       → Do NOT say phrases like:
         "does not include specific data",
         "insufficient information",
         "no data available".

2. WHEN the "Information" section is EMPTY or truly irrelevant:
   - Answer in a general advisory manner.
   - Provide strategy-oriented guidance.
   - Avoid disclaimers about missing data.

3. IF the user asks about investing (e.g., "should I buy", "is it good time"):
   - You MUST use the provided price and news data.
   - Start by mentioning:
       → current price movement (up/down based on change)
       → recent sentiment (from news)
   - Then provide a balanced interpretation:
       → positive signals → mention growth potential
       → negative signals → mention caution
   - NEVER give generic advice without using the data.
   - NEVER ignore the provided data.
   - Avoid definitive statements like "definitely buy".
   - Use phrases like:
       "based on current trend", "shows positive momentum", "may require caution".

STYLE GUIDELINES:
- Prefer bullets or short paragraphs.
- Confident, explanatory tone.
- No mention of tools, databases, or system limitations.

OUTPUT RULES:
- If data exists → summarize what it indicates.
- If data is news-based → frame conclusions as news-driven momentum, not price performance.

MANDATORY:
- End with:
  "💡 You may also ask:"
- Suggest 2–3 short, relevant follow-up questions.
"""


# ============================
# 🧠 TOOL DECISION PROMPT
# ============================
TOOL_DECISION_PROMPT = f"""
IMPORTANT:
- Today's date is {datetime.now(IST).strftime("%Y-%m-%d")} (IST).
- Never guess dates.
- If a date is mentioned or implied, resolve it carefully.

If the question asks about "top performing stocks" but the information
contains only news-based signals (sentiment, impact, headlines):
- Reframe the answer as "stocks with strong positive news momentum"
- Do NOT claim price performance
- Clearly present it as news-driven performance


DATE RESOLUTION RULES:
- "today" → today’s date
- "yesterday" → today - 1 day
- "day before yesterday" → today - 2 days
- "last week" → today - 7 days
- "last month" → today - 30 days
- Explicit dates (e.g. "Jan 15", "15 Jan 2026") → convert to YYYY-MM-DD
- If the user asks about a previous day or past date, ALWAYS treat it as a date-based query.

TOOL SELECTION RULES:

1. If the user asks about:
   - market performance on any date
   - top performing stocks on a previous date
   - yesterday / last week / any past day
   - market conditions on a specific date

   → YOU MUST call: get_market_news_by_date
   → Pass the resolved date in YYYY-MM-DD format.

2. If the user asks about:
   - current price
   - stock price
   - price of [company]
   - what is the price
   - how much is [company]
   - [company] price
   - trading price
   - share price
   - stock value
   - current value
   - trading at
   - a specific company
   - company performance
   - company-related news

   → YOU MUST call: finedge_company_tool

3. If the user asks to search news by keyword or topic:
   → YOU MAY call: search_news

4. If the user asks for latest general news:
   → YOU MAY call: get_latest_news
5. If user asks about:
   - company fundamentals
   - financials
   - revenue, profit, balance sheet
   - analysis of a company

   → YOU MUST call: finedge_full_analysis_tool

IMPORTANT:
- Always prefer tools when factual market or historical data is requested.
- Never explain your decision.
"""

SYSTEM_FALLBACK_PROMPT = f"""
You are a financial assistant.

CONTEXT:
- Today's date is {today} (IST).

CORE RULES:
- Respond helpfully and naturally.
- NEVER mention:
  - lack of access
  - missing or unavailable data
  - system or tool limitations
  - phrases such as:
    "I can't provide",
    "not available",
    "I don't have the data",
    "check another source",
    "latest price is unavailable".
- NEVER invent prices, index values, or numeric figures.
- If financial data is present:
  → Summarize revenue, profit, or key metrics.
- If quote data exists:
  → Mention price and change clearly.
- If both news and financials exist:
  → Combine insights into a clear company outlook.

WHEN A QUESTION ASKS FOR A CURRENT / LIVE NUMERIC VALUE
AND NO VERIFIED NUMBER IS PROVIDED:
- Do NOT refuse the question.
- Do NOT say the data is missing.
- Do NOT give an exact number.
- Instead:
  - Explain what the asset or index represents.
  - Explain what typically influences its movement.
  - Keep the explanation aligned with the user’s intent.

STYLE:
- Calm, confident, and informative.
- Short paragraphs or bullet points.
- No apologies, no disclaimers, no system references.

EXAMPLE OUTPUTS (FOLLOW THIS PATTERN):

Example 1:
User question:
"Current price of Nifty index"

Good answer:
"The Nifty index represents the performance of India’s 50 largest listed companies and moves continuously during market hours based on buying and selling activity.
Its movement is mainly influenced by heavyweight sectors such as banking, IT, and energy, along with global market cues and domestic economic indicators."

Example 2:
User question:
"Live price of Reliance Industries"

Good answer:
"A stock’s price reflects how investors currently value the company based on earnings expectations, business performance, and overall market sentiment.
For large companies like Reliance Industries, price movements are often driven by quarterly results, performance of key business segments, and broader market trends."

MANDATORY:
- End every response with:
  "💡 You may also ask:"
- Suggest 2–3 relevant follow-up questions.
"""


# ============================
# OPENAI CLIENT
# ============================
def get_openai_client():
    return OpenAI(api_key=OPENAI_API_KEY)

# ============================
# TOOLS (LLM SEES THESE)
# ============================
TOOLS = [
    {
        "type": "function",
        "function": {
            "name": "search_news",
            "description": "Search news by keyword",
            "parameters": {
                "type": "object",
                "properties": {
                    "query": {"type": "string"}
                },
                "required": ["query"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "get_latest_news",
            "description": "Get the latest general news",
            "parameters": {"type": "object", "properties": {}}
        }
    },
    
    {
        "type": "function",
        "function": {
            "name": "get_news_by_sentiment",
            "description": "Get news filtered by sentiment",
            "parameters": {
                "type": "object",
                "properties": {
                    "sentiment": {"type": "string"}
                },
                "required": ["sentiment"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "get_news_by_impact",
            "description": "Get news filtered by impact",
            "parameters": {
                "type": "object",
                "properties": {
                    "impact": {"type": "string"}
                },
                "required": ["impact"]
            }
        }
    },
    { 
        "type": "function",
        "function":  {
            "name": "finedge_company_tool",
            "description": "Get real-time stock price, company quote data, and related news for a specific company. Use this when user asks about current price, stock value, or company performance.",
            "parameters": {
                "type": "object",
                "properties": {
                "company": { "type": "string", "description": "Company name or stock symbol" },
                "limit": { "type": "integer", "default": 5 }
                },
                "required": ["company"]
        }
    }
},
   
   {
    "type": "function",
    "function": {
        "name": "get_market_news_by_date",
        "description": "Use this tool when the user asks about market conditions for today, yesterday, or any specific date. Extract the date from the question and pass it in YYYY-MM-DD format.",
        "parameters": {
            "type": "object",
            "properties": {
                "date": {
                    "type": "string",
                    "description": "Date in YYYY-MM-DD format"
                },
                "limit": {
                    "type": "integer",
                    "default": 10
                }
            },
            "required": ["date"]
        }
    }
},
{
    "type": "function",
    "function": {
        "name": "finedge_full_analysis_tool",
        "description": "Get full financial analysis including revenue, profit, ratios, and stock data",
        "parameters": {
            "type": "object",
            "properties": {
                "company": {"type": "string"}
            },
            "required": ["company"]
        }
    }
}

]

# ============================
# TOOL MAP (EXECUTION)
# ============================
TOOL_MAP = {
    "search_news":search_news,
    "get_latest_news":get_latest_news,
    "get_news_by_sentiment": get_news_by_sentiment,
    "get_news_by_impact": get_news_by_impact,
    "finedge_company_tool": finedge_company_tool,
    "get_market_news_by_date": get_market_news_by_date,
    "finedge_full_analysis_tool": finedge_full_analysis_tool,
}


def is_tool_result_relevant(question: str, tool_name: str, tool_result: dict) -> bool:
    q = question.lower()

    # Always trust company tools
    if tool_name in ["finedge_company_tool", "finedge_full_analysis_tool"]:
        return True

    # Market date queries
    if any(word in q for word in ["market", "yesterday", "performed", "stocks", "date"]):
        return bool(tool_result.get("news"))

    return False

def has_valid_price_data(tool_result):
    try:
        return tool_result.get("quote", {}).get("price") not in [None, "", "Not Available"]
    except:
        return False

def is_investment_query(question: str) -> bool:
    q = question.lower()
    return any(word in q for word in [
        "buy", "invest", "should i", "good time", "worth", "hold", "sell"
    ])
# ============================
# MAIN LLM FUNCTION
# ============================
def ask_llm(question: str) -> str:
    print("\n==============================")
    print("USER QUESTION:", question)
    print("==============================")

    global CHAT_HISTORY

    client = get_openai_client()

    # -------- Tool decision step (LLM ONLY) --------
    is_price_query = any(word in question.lower() for word in [
    "price", "current price", "stock price", "share price", "trading price"
])
    is_investment = is_investment_query(question),
    
    response = client.chat.completions.create(
        model="gpt-4o-mini",
        messages=[
            {"role": "system", "content": TOOL_DECISION_PROMPT},
            *CHAT_HISTORY,
            {"role": "user", "content": question},
        ],
        tools=TOOLS,

        tool_choice = "required" if (is_price_query or is_investment) else "auto",
        temperature=0,
    )

    msg = response.choices[0].message

    if msg.tool_calls:
        print("🔧 TOOL CHOSEN BY LLM:", msg.tool_calls[0].function.name)
        print("📦 RAW TOOL ARGS:", msg.tool_calls[0].function.arguments)
    else:
        print("🧠 NO TOOL CHOSEN — LLM ANSWERING DIRECTLY")


    # -------- Tool execution path --------
    if msg.tool_calls:
        tool_call = msg.tool_calls[0]
        tool_name = tool_call.function.name
        args = json.loads(tool_call.function.arguments or "{}")

        print("▶️ EXECUTING TOOL:", tool_name)
        print("▶️ WITH ARGUMENTS:", args)

        tool_result = TOOL_MAP[tool_name](**args)

        if isinstance(tool_result, dict):
            print("✅ TOOL EXECUTED SUCCESSFULLY")
            print("📊 RESULT KEYS:", list(tool_result.keys()))
            if "count" in tool_result:
                print("📰 NEWS COUNT:", tool_result["count"])
        elif isinstance(tool_result, list):
            print("✅ TOOL EXECUTED SUCCESSFULLY")
            print("📰 ITEMS RETURNED:", len(tool_result))
        else:
            print("⚠️ TOOL RETURNED UNKNOWN FORMAT")

        # 🔥 Handle both dict and list results
        if isinstance(tool_result, list):
            # If tool returns a list, wrap it in a dict
            clean_result = {"news": tool_result}
        else:
            clean_result = tool_result.copy()
            # 🚀 remove symbol from response
            if "symbol" in clean_result:
                del clean_result["symbol"]

        # 🔥 Check if tool result is useful
        is_investment = is_investment_query(question)
        
        # Safe access for both dict and list
        if isinstance(tool_result, dict):
            has_price = has_valid_price_data(tool_result)
            has_news = bool(tool_result.get("news"))
        else:
            has_price = False
            has_news = bool(tool_result)  # List is truthy if not empty

        if has_price or (is_investment and has_news):
            if isinstance(tool_result, dict):
                clean_result = tool_result.copy()
                clean_result.pop("symbol", None)
                enhanced_info = {
                    "price_data": clean_result.get("quote"),
                    "news_signals": clean_result.get("news"),
                    "analysis_hint": "Use price trend and news sentiment to answer investment questions"
                }
            else:
                # For list results
                enhanced_info = {
                    "news_signals": tool_result,
                    "analysis_hint": "Use news sentiment to answer the question"
                }

            final = client.chat.completions.create(
                model="gpt-4o-mini",
                messages=[
                    {"role": "system", "content": SYSTEM_FINAL_PROMPT},
                    *CHAT_HISTORY,
                    {
                        "role": "user",
                        "content": f"{question}\n\nInformation:\n{json.dumps(enhanced_info)}",
                    },
                ],
                temperature=0.4,
                max_tokens=300
            )
        else:
            # 🚀 FALLBACK DIRECTLY
            final = client.chat.completions.create(
                model="gpt-4o-mini",
                messages=[
                    {"role": "system", "content": SYSTEM_FALLBACK_PROMPT},
                    *CHAT_HISTORY,
                    {"role": "user", "content": question},
                ],
                temperature=0.6,
            )


        answer = final.choices[0].message.content

    # -------- No tool path --------
    else:
        final = client.chat.completions.create(
            model="gpt-4o-mini",
            messages=[
                {"role": "system", "content": SYSTEM_FINAL_PROMPT},
                *CHAT_HISTORY,
                {"role": "user", "content": question},
            ],
            temperature=0.6,
        )

        answer = final.choices[0].message.content

    # -------- Save memory --------
    CHAT_HISTORY.append({"role": "user", "content": question})
    CHAT_HISTORY.append({"role": "assistant", "content": answer})

    return answer