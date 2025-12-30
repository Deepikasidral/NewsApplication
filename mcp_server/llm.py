import json
from openai import AzureOpenAI
from mcp_server.config import (
    AZURE_OPENAI_ENDPOINT,
    AZURE_OPENAI_KEY,
    AZURE_DEPLOYMENT
)
from mcp_server.tools import (
    search_news,
    get_latest_news,
    get_news_by_company,
    get_news_by_sentiment,
    get_news_by_impact,
)

# ============================
# 🔐 FINAL SYSTEM PROMPT
# ============================
SYSTEM_FINAL_PROMPT = """
You are a smart and knowledgeable financial assistant.

Follow these rules:
- Respond like ChatGPT with clear structure, headings, bullet points, and bold text when helpful.
- Use emojis naturally to improve readability.
- Never mention tools, databases, filters, storage, or sources.
- Never say phrases like "based on the data", "according to news records", or "from the database".
- If information is available, blend it naturally into your response.
- If information is missing, answer confidently using your general financial knowledge.
- Keep the tone professional, clear, and easy to understand.
"""


client = AzureOpenAI(
    api_key=AZURE_OPENAI_KEY,
    azure_endpoint=AZURE_OPENAI_ENDPOINT,
    api_version="2024-02-01",
)

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
            "description": "Get latest news",
            "parameters": {"type": "object", "properties": {}}
        }
    },
    {
        "type": "function",
        "function": {
            "name": "get_news_by_company",
            "description": "Get news related to a specific company",
            "parameters": {
                "type": "object",
                "properties": {
                    "company": {"type": "string"}
                },
                "required": ["company"]
            }
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
    }
]

TOOL_MAP = {
    "search_news": search_news,
    "get_latest_news": get_latest_news,
    "get_news_by_company": get_news_by_company,
    "get_news_by_sentiment": get_news_by_sentiment,
    "get_news_by_impact": get_news_by_impact,
}


def ask_llm(question: str) -> str:
    # Step 1: Let model decide tool usage
    response = client.chat.completions.create(
        model=AZURE_DEPLOYMENT,
        messages=[
            {
                "role": "system",
                "content": (
                    "You are a smart financial assistant. "
                    "Decide if a tool is required to answer the user's question."
                ),
            },
            {"role": "user", "content": question},
        ],
        tools=TOOLS,
        tool_choice="auto",
        temperature=0,
    )

    msg = response.choices[0].message

    # Step 2: Tool call path
    if msg.tool_calls:
        tool_call = msg.tool_calls[0]
        tool_name = tool_call.function.name
        args = json.loads(tool_call.function.arguments)

        tool_result = TOOL_MAP[tool_name](**args)

        # Step 3: If tool has no data → fallback to LLM knowledge
        if not tool_result:
            fallback = client.chat.completions.create(
                model=AZURE_DEPLOYMENT,
                messages=[
                    {"role": "system", "content": SYSTEM_FINAL_PROMPT},
                    {"role": "user", "content": question},
                ],
                temperature=0.6,
            )
            return fallback.choices[0].message.content

        # Step 4: Reason over data silently
        final_response = client.chat.completions.create(
            model=AZURE_DEPLOYMENT,
            messages=[
                {"role": "system", "content": SYSTEM_FINAL_PROMPT},
                {
                    "role": "user",
                    "content": (
                        f"{question}\n\n"
                        f"Information:\n{json.dumps(tool_result)}"
                    ),
                },
            ],
            temperature=0.4,
        )

        return final_response.choices[0].message.content

    # Step 5: No tool needed
    return msg.content
