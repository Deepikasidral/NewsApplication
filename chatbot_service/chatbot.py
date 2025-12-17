# from groq import Groq
# import os
# import json
# from dotenv import load_dotenv
# from mcp_server.tools import mcp
# from mcp.types import TextContent



# # Load environment variables
# load_dotenv()

# # Groq client
# groq = Groq(api_key=os.getenv("GROQ_API_KEY"))

# # ==============================
# # 🔒 STRICT SYSTEM PROMPT
# # ==============================
# SYSTEM_PROMPT = """
# You are Rupee Letter AI.

# STRICT RULES:
# - You MUST call exactly one provided tool to answer.
# - You are NOT allowed to answer from your own knowledge.
# - You are NOT allowed to mention real-time information.
# - If the tool returns no data, respond with exactly:
#   "I don't have information in my database."
# - Do NOT generate generic, advisory, or explanatory answers.
# """

# # ==============================
# # 🧠 TOOLS EXPOSED TO LLM
# # ==============================
# TOOLS = [
#     {
#         "type": "function",
#         "function": {
#             "name": "get_latest_news",
#             "description": "Get the latest stock market news"
#         }
#     },
#     {
#         "type": "function",
#         "function": {
#             "name": "get_news_by_company",
#             "description": "Get news related to a specific company"
#         }
#     },
#     {
#         "type": "function",
#         "function": {
#             "name": "get_news_by_sentiment",
#             "description": "Get news filtered by sentiment (Positive, Neutral, Negative)"
#         }
#     },
#     {
#         "type": "function",
#         "function": {
#             "name": "search_news",
#             "description": "Search news by keyword, topic, city, or general query",
#             "parameters": {
#                 "type": "object",
#                 "properties": {
#                     "query": {"type": "string"},
#                     "limit": {"type": "integer"}
#                 },
#                 "required": ["query"]
#             }
#         }
#     }
# ]

# # ==============================
# # 🤖 MAIN CHAT FUNCTION
# # ==============================
# async def ask_bot(question: str) -> str:
#     """
#     Chatbot that answers ONLY using MCP tools + MongoDB.
#     """

#     # 1️⃣ Ask LLM which tool to use
#     response = groq.chat.completions.create(
#         model="llama-3.1-8b-instant",
#         messages=[
#             {"role": "system", "content": SYSTEM_PROMPT},
#             {"role": "user", "content": question},
#         ],
#         tools=TOOLS,
#         tool_choice="auto",
#         temperature=0.0
#     )

#     msg = response.choices[0].message

#     # 🚫 LLM did NOT call any tool → BLOCK
#     if not msg.tool_calls:
#         return "I don't have information in my database."

#     # 2️⃣ Extract tool call
#     tool_call = msg.tool_calls[0]
#     tool_name = tool_call.function.name

#     try:
#         args = json.loads(tool_call.function.arguments or "{}")
#     except json.JSONDecodeError:
#         args = {}

#     # 3️⃣ Call MCP tool (ASYNC)
#     try:
#         tool_result = await mcp.call_tool(tool_name, args)
#     except Exception:
#         return "I don't have information in my database."

#     # 4️⃣ Convert MCP TextContent → plain text
   

#   # Convert MCP result → usable text (version-safe)
#     tool_text_parts = []

#     if isinstance(tool_result, list):
#         for content in tool_result:
#             # Case 1: TextContent
#             if isinstance(content, TextContent):
#                 if content.text.strip():
#                     tool_text_parts.append(content.text)

#             # Case 2: JSON-like content (no JsonContent class)
#             elif hasattr(content, "data"):
#                 tool_text_parts.append(
#                     json.dumps(content.data, indent=2)
#                 )

#     tool_text = "\n".join(tool_text_parts)

#     if not tool_text.strip():
#         return "I don't have information in my database."


#     # 5️⃣ Ask LLM to format answer ONLY from tool output
#     return tool_text


#Working code

# from groq import Groq
# import os
# import json
# from dotenv import load_dotenv
# from mcp_server.tools import mcp
# from mcp.types import TextContent

# # ==============================
# # 🔧 ENV + CLIENT SETUP
# # ==============================
# load_dotenv()

# groq = Groq(api_key=os.getenv("GROQ_API_KEY"))

# # ==============================
# # 🧠 SIMPLE ROUTING LOGIC
# # ==============================
# def decide_tool(question: str):
#     """
#     Decide which MCP tool to use based on the question.
#     This is deterministic and stable.
#     """
#     q = question.lower()

#     # Company keywords (extend later using DB)
#     known_companies = [
#         "havells",
#         "tata",
#         "reliance",
#         "infosys",
#         "hdfc",
#         "icici",
#         "sbi",
#         "au small finance bank"
#     ]

#     for company in known_companies:
#         if company in q:
#             return "get_news_by_company", {"company": company}

#     # Sentiment-based
#     if "positive" in q or "negative" in q or "neutral" in q:
#         sentiment = "positive" if "positive" in q else "negative" if "negative" in q else "neutral"
#         return "get_news_by_sentiment", {"sentiment": sentiment}

#     # Latest news
#     if "latest" in q or "today" in q:
#         return "get_latest_news", {"limit": 5}

#     # Fallback → keyword search
#     return "search_news", {"query": question}


# # ==============================
# # 🤖 MAIN CHAT FUNCTION
# # ==============================
# async def ask_bot(question: str) -> str:
#     """
#     Stable DB-backed chatbot.
#     - No LLM tool calling
#     - MCP is the source of truth
#     - Groq only formats output
#     """

#     tool_name, args = decide_tool(question)

#     # 1️⃣ Call MCP tool
#     try:
#         tool_result = await mcp.call_tool(tool_name, args)
#     except Exception:
#         return "I don't have information in my database."

#     # 2️⃣ Convert MCP output → text
#     tool_text_parts = []

#     if isinstance(tool_result, list):
#         for content in tool_result:
#             if isinstance(content, TextContent) and content.text.strip():
#                 tool_text_parts.append(content.text)
#             elif hasattr(content, "data"):
#                 tool_text_parts.append(json.dumps(content.data, indent=2))

#     tool_text = "\n".join(tool_text_parts)

#     if not tool_text.strip():
#         return "I don't have information in my database."

#     # 3️⃣ OPTIONAL: Summarize using Groq (NO TOOLS)
#     summary = groq.chat.completions.create(
#         model="llama-3.1-8b-instant",
#         messages=[
#             {
#                 "role": "system",
#                 "content": (
#                     "You are a financial news assistant. "
#                     "Summarize the following news clearly and briefly. "
#                     "Do NOT add new information."
#                 ),
#             },
#             {"role": "user", "content": tool_text},
#         ],
#         temperature=0.0
#     )

#     return summary.choices[0].message.content

# chatbot_service/chatbot.py
from groq import Groq
import os
from dotenv import load_dotenv
from chatbot_service.tool_registry import TOOL_REGISTRY
from chatbot_service.company_cache import load_companies


load_dotenv()
groq = Groq(api_key=os.getenv("GROQ_API_KEY"))

KEYWORDS, COMPANY_MAP = load_companies()
GENERIC_WORDS = {
    "bank", "banks",
    "india", "indian",
    "limited", "ltd",
    "finance", "financial",
    "capital", "services",
    "group", "company",
    "co", "plc"
}


def detect_company(question: str):
    q = question.lower()

    for key in KEYWORDS:  # already sorted longest → shortest
        if key in GENERIC_WORDS:
            continue  # 🚫 skip generic words

        if key in q:
            return COMPANY_MAP.get(key)

    return None


def decide_tool(question: str):
    q = question.lower()

    # 1️⃣ IMPACT (FIRST)
    impact_map = {
        "very high impact": "Very High",
        "high impact": "High",
        "major impact": "High",
        "big impact": "High",
        "mild impact": "Mild",
        "low impact": "Negligible",
        "negligible impact": "Negligible",
    }
    for phrase, value in impact_map.items():
        if phrase in q:
            return "get_news_by_impact", {"impact": value}

    # 2️⃣ SENTIMENT
    sentiment_map = {
        "very bullish": "Very Bullish",
        "bullish": "Bullish",
        "neutral": "Neutral",
        "bearish": "Bearish",
        "very bearish": "Very Bearish",
    }
    for phrase, value in sentiment_map.items():
        if phrase in q:
            return "get_news_by_sentiment", {"sentiment": value}

    # 3️⃣ SECTOR
    if "general market" in q or "market news" in q:
        return "get_news_by_sector", {"sector": "General Market"}

    if "company specific" in q:
        return "get_news_by_sector", {"sector": "Company Specific"}

    # 4️⃣ COMPANY (AFTER FILTERS)
    company = detect_company(question)
    if company:
        return "get_news_by_company", {"company": company}

    # 5️⃣ CITY
    cities = ["delhi", "mumbai", "pune", "bangalore", "chennai"]
    for city in cities:
        if city in q:
            return "search_news", {"query": city}

    # 6️⃣ LATEST
    if "latest" in q or "today" in q:
        return "get_latest_news", {"limit": 5}

    # 7️⃣ FALLBACK
    return "search_news", {"query": question}



def ask_bot(question: str) -> str:
    tool_name, args = decide_tool(question)

    print(f"📢 Calling tool: {tool_name} with args: {args}")

    tool_fn = TOOL_REGISTRY.get(tool_name)

    if not tool_fn:
        print("❌ Tool not found")
        return "I don't have information in my database."

    try:
        results = tool_fn(**args)
    except Exception as e:
        print("❌ Tool execution error:", e)
        return "I don't have information in my database."

    if not results:
        return "I don't have information in my database."

    # Convert DB docs → text
    blocks = []
    for doc in results:
        blocks.append(
            f"Headline: {doc.get('Headline','')}\n"
            f"Summary: {doc.get('summary','')}\n"
            f"Sentiment: {doc.get('sentiment','')}\n"
            f"Impact: {doc.get('impact','')}"
        )

    context = "\n\n".join(blocks)

    # Summarize
    response = groq.chat.completions.create(
        model="llama-3.1-8b-instant",
        messages=[
            {
                "role": "system",
                "content": (
                    "You are a financial news assistant. "
                    "Summarize the following news clearly and briefly. "
                    "Do not add new information."
                ),
            },
            {"role": "user", "content": context},
        ],
        temperature=0.0,
    )

    return response.choices[0].message.content



