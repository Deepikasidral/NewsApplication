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
    # 1️⃣ LLM decides which tool to use
    response = client.chat.completions.create(
        model=AZURE_DEPLOYMENT,
        messages=[
            {
                "role": "system",
                "content": (
                    "You are a smart financial news assistant. "
                    "Understand the user's intent and decide which tool to use."
                ),
            },
            {"role": "user", "content": question},
        ],
        tools=TOOLS,
        tool_choice="auto",
        temperature=0,
    )

    msg = response.choices[0].message

    # 2️⃣ Tool selected
    if msg.tool_calls:
        tool_call = msg.tool_calls[0]
        tool_name = tool_call.function.name
        args = json.loads(tool_call.function.arguments)

        tool_result = TOOL_MAP[tool_name](**args)

        if not tool_result:
            return "🤔 I couldn't find any relevant news for your query."

        # 3️⃣ GPT-style reasoning over query + data
        final_response = client.chat.completions.create(
            model=AZURE_DEPLOYMENT,
            messages=[
                {
                    "role": "system",
                    "content": (
                        "You are a friendly financial assistant. "
                        "Answer the user's question using the provided news data. "
                        "Use simple language, be clear and helpful. "
                        "Include relevant emojis where appropriate. "
                        "Do NOT mention JSON, databases, or tools."
                    ),
                },
                {
                    "role": "user",
                    "content": (
                        f"User question:\n{question}\n\n"
                        f"Relevant news data:\n{json.dumps(tool_result, indent=2)}"
                    ),
                },
            ],
            temperature=0.4,
        )

        return final_response.choices[0].message.content

    # 4️⃣ No tool needed → normal GPT answer
    return msg.content
