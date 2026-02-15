import logging
from pymongo import MongoClient
from config import MONGO_URI, DB_NAME

logger = logging.getLogger(__name__)

try:
    client = MongoClient(MONGO_URI)
    db = client[DB_NAME]
    filtered_news = db["filtered_news"]
    logger.info("✅ MongoDB connected successfully")
except Exception:
    logger.exception("❌ MongoDB connection failed")
    raise