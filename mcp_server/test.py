from mcp_server.tools import mcp

print("Latest news:")
print(mcp.call("get_latest_news", limit=2))

print("\nSearch news:")
print(mcp.call("search_news", query="market", limit=2))

print("\nCompany news:")
print(mcp.call("get_news_by_company", company="Tata", limit=2))

