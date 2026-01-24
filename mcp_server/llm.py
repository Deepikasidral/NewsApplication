# import json
# from openai import OpenAI
# from datetime import datetime
# from pytz import timezone



# from mcp_server.config import OPENAI_API_KEY

# from mcp_server.tools import (
#     search_news,
#     get_latest_news,
#     get_news_by_company,
#     get_news_by_sentiment,
#     get_news_by_impact,
#     finedge_company_tool,
#     get_todays_market_news,

# )


# # ============================
# # TEMP 1-TURN CHAT MEMORY
# # ============================
# # ============================
# # MULTI-TURN CHAT MEMORY
# # ============================

# IST = timezone("Asia/Kolkata")
# today = datetime.now(IST).strftime("%B %d, %Y")
# CHAT_HISTORY = []


# # ============================
# # 🔐 FINAL SYSTEM PROMPT
# # ============================
# SYSTEM_FINAL_PROMPT = f"""
# You are a smart and knowledgeable financial assistant.

# IMPORTANT CONTEXT:
# - Today's date is {today} (IST).
# - Always use today's date when mentioning market timelines.
# - Never assume or invent dates.

# Follow these rules:
# - Respond like ChatGPT with clear structure, headings, bullet points, and bold text when helpful.
# - Use emojis naturally to improve readability.
# - Never mention tools, databases, filters, storage, or sources.
# - Never say phrases like "based on the data", "according to news records", or "from the database".
# - If information is available, blend it naturally into your response.
# - If information is missing, answer confidently using your general financial knowledge.
# - Keep the tone professional, clear, and easy to understand.
# - Never say something like "A tool is not required to answer your question".

# IMPORTANT:
# - After completing the main answer, ALWAYS add a section titled:
#   "💡 You may also ask:"
# - Under it, suggest 2–3 short, relevant follow-up questions a user might naturally ask next.
# - The follow-up questions should be conversational and useful.
# """



# def get_openai_client():
#     return OpenAI(
#         api_key=OPENAI_API_KEY
#     )


# TOOLS = [
#     {
#         "type": "function",
#         "function": {
#             "name": "search_news",
#             "description": "Search news by keyword",
#             "parameters": {
#                 "type": "object",
#                 "properties": {
#                     "query": {"type": "string"}
#                 },
#                 "required": ["query"]
#             }
#         }
#     },
#     {
#         "type": "function",
#         "function": {
#             "name": "get_latest_news",
#             "description": "Get latest news",
#             "parameters": {"type": "object", "properties": {}}
#         }
#     },
#     {
#         "type": "function",
#         "function": {
#             "name": "get_news_by_company",
#             "description": "Get news related to a specific company",
#             "parameters": {
#                 "type": "object",
#                 "properties": {
#                     "company": {"type": "string"}
#                 },
#                 "required": ["company"]
#             }
#         }
#     },
#     {
#         "type": "function",
#         "function": {
#             "name": "get_news_by_sentiment",
#             "description": "Get news filtered by sentiment",
#             "parameters": {
#                 "type": "object",
#                 "properties": {
#                     "sentiment": {"type": "string"}
#                 },
#                 "required": ["sentiment"]
#             }
#         }
#     },
#     {
#         "type": "function",
#         "function": {
#             "name": "get_news_by_impact",
#             "description": "Get news filtered by impact",
#             "parameters": {
#                 "type": "object",
#                 "properties": {
#                     "impact": {"type": "string"}
#                 },
#                 "required": ["impact"]
#             }
#         }
#     },
#     {
#     "type": "function",
#     "function": {
#         "name": "finedge_company_tool",
#         "description": "Get today's market news with very high impact and extreme sentiment",
#         "parameters": {
#             "type": "object",
#             "properties": {
#                 "limit": {
#                     "type": "integer",
#                     "default": 10
#                 }
#             }
#         }
#     }
# },
# {
#     "type": "function",
#     "function": {
#         "name": "get_todays_market_news",
#         "description": "Get today's market news with very high impact and extreme sentiment",
#         "parameters": {
#             "type": "object",
#             "properties": {
#                 "limit": {
#                     "type": "integer",
#                     "default": 10
#                 }
#             }
#         }
#     }
# }


# ]

# TOOL_MAP = {
#     "search_news": search_news,
#     "get_latest_news": get_latest_news,
#     "get_news_by_company": get_news_by_company,
#     "get_news_by_sentiment": get_news_by_sentiment,
#     "get_news_by_impact": get_news_by_impact,
#     "finedge_company_tool":finedge_company_tool,
#     "get_todays_market_news":get_todays_market_news
# }


# def ask_llm(question: str) -> str:
#     global CHAT_HISTORY

#     client = get_openai_client()

#     # ============================
#     # BUILD CONTEXT FROM MEMORY
#     # ============================
#     messages_for_tool_decision = []

#     for msg in CHAT_HISTORY:
#         messages_for_tool_decision.append(msg)

#     messages_for_tool_decision.append(
#         {"role": "user", "content": question}
#     )
#     # ============================
# # FORCE TOOLS FOR MARKET QUERIES
# # ============================
#     force_tool = any(
#         k in question.lower()
#         for k in ["today", "market", "trend", "sentiment"]
#     )

#     tool_choice = "required" if force_tool else "auto"


#     # ============================
#     # STEP 1: TOOL DECISION
#     # ============================
#     response = client.chat.completions.create(
#         model="gpt-4o-mini",
#         messages=[
#             {
#                 "role": "system",
#                 "content": "Decide whether a tool is required. Do NOT explain your decision."
#             },
#             *messages_for_tool_decision
#         ],
#         tools=TOOLS,
#         tool_choice=tool_choice,   # 👈 USE IT HERE
#         temperature=0,
#     )

#     msg = response.choices[0].message

#     # ============================
#     # TOOL PATH (UNCHANGED)
#     # ============================
#     if msg.tool_calls:
#         tool_call = msg.tool_calls[0]
#         tool_name = tool_call.function.name
#         args = json.loads(tool_call.function.arguments)

#         tool_result = TOOL_MAP[tool_name](**args)

#         # Tool returned nothing → fallback to LLM
#         if not tool_result:
#             final = client.chat.completions.create(
#                 model="gpt-4o-mini",
#                 messages=[
#                     {"role": "system", "content": SYSTEM_FINAL_PROMPT},
#                     *CHAT_HISTORY,
#                     {"role": "user", "content": question},
#                 ],
#                 temperature=0.6,
#             )

#             answer = final.choices[0].message.content

#         else:
#             # Tool has data → reason silently
#             final = client.chat.completions.create(
#                 model="gpt-4o-mini",
#                 messages=[
#                     {"role": "system", "content": SYSTEM_FINAL_PROMPT},
#                     *CHAT_HISTORY,
#                     {
#                         "role": "user",
#                         "content": (
#                             f"{question}\n\n"
#                             f"Information:\n{json.dumps(tool_result)}"
#                         ),
#                     },
#                 ],
#                 temperature=0.4,
#             )

#             answer = final.choices[0].message.content

#     # ============================
#     # NO TOOL NEEDED (UNCHANGED)
#     # ============================
#     else:
#         final = client.chat.completions.create(
#             model="gpt-4o-mini",
#             messages=[
#                 {"role": "system", "content": SYSTEM_FINAL_PROMPT},
#                 *CHAT_HISTORY,
#                 {"role": "user", "content": question},
#             ],
#             temperature=0.6,
#         )

#         answer = final.choices[0].message.content

#     # ============================
#     # SAVE TO MEMORY (NEW)
#     # ============================
#     CHAT_HISTORY.append({"role": "user", "content": question})
#     CHAT_HISTORY.append({"role": "assistant", "content": answer})

#     return answer

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
   - a specific company
   - stock price
   - company performance
   - company-related news

   → YOU MUST call: finedge_company_tool

3. If the user asks to search news by keyword or topic:
   → YOU MAY call: search_news

4. If the user asks for latest general news:
   → YOU MAY call: get_latest_news

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
            "parameters": {
                "type": "object",
                "properties": {
                "company": { "type": "string" },
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
}


def is_tool_result_relevant(question: str, tool_name: str, tool_result: dict) -> bool:
    q = question.lower()

    # -------- PRICE / VALUE QUERIES (INDEX or STOCK) --------
    if any(word in q for word in ["price", "current", "value", "level"]):
        if tool_name == "finedge_company_tool":
            quote = tool_result.get("quote", {})
            return quote.get("price") is not None

        # Any other tool is irrelevant for price
        return False

    # -------- DATE / MARKET PERFORMANCE QUERIES --------
    if any(word in q for word in ["market", "yesterday", "performed", "stocks", "date"]):
        if tool_name == "get_market_news_by_date":
            return bool(tool_result.get("news"))
        return False

    # -------- DEFAULT: tool not relevant --------
    return False

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
    response = client.chat.completions.create(
        model="gpt-4o-mini",
        messages=[
            {"role": "system", "content": TOOL_DECISION_PROMPT},
            *CHAT_HISTORY,
            {"role": "user", "content": question},
        ],
        tools=TOOLS,
        tool_choice="auto",
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


        use_tool = is_tool_result_relevant(question, tool_name, tool_result)

        if use_tool:
            # Tool is relevant → pass data
            final = client.chat.completions.create(
                model="gpt-4o-mini",
                messages=[
                    {"role": "system", "content": SYSTEM_FINAL_PROMPT},
                    *CHAT_HISTORY,
                    {
                        "role": "user",
                        "content": f"{question}\n\nInformation:\n{json.dumps(tool_result)}",
                    },
                ],
                temperature=0.4,
                max_tokens=300
            )
        else:
            # Tool is irrelevant → IGNORE it completely
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
