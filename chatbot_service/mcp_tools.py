import requests

BASE_URL = "http://localhost:8000"

def call_mcp_tool(tool_name: str, arguments: dict):
    url = f"{BASE_URL}/{tool_name}"
    response = requests.post(url, params=arguments)
    response.raise_for_status()
    return response.json()
