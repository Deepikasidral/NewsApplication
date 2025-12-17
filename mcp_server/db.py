from pymongo import MongoClient
from mcp_server.config import MONGO_URI, DB_NAME

client = MongoClient(MONGO_URI)
db = client[DB_NAME]

filtered_news = db["filtered_news"]

