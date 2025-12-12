import os
from dotenv import load_dotenv
from pymongo import MongoClient

# ===============================
# 🔧 CONFIGURATION
# ===============================
load_dotenv(dotenv_path="../.env")

mongo_uri = os.getenv("MONGO_URI")
db_name = os.getenv("DB_NAME")
collection_name = os.getenv("COLLECTION_NAME")  # raw news collection
client = MongoClient(mongo_uri)
db = client[db_name]

all_news = db[collection_name]     # raw news
filtered_news = db["filtered_news"]  # filtered news

# ===============================
# 🧹 CLEANUP FUNCTION
# ===============================
def reset_testing_data():
    """
    Deletes all docs in 'filtered_news' and removes specific test fields from 'raw_news'.
    """
    try:
        # 1️⃣ Delete filtered_news data
        deleted = filtered_news.delete_many({})
        print(f"🗑️ Deleted {deleted.deleted_count} docs from 'filtered_news'.")

        # 2️⃣ Unset fields in raw news
        update_result = all_news.update_many(
            {},
            {"$unset": {
                "processed_by_agent1": "",
                "decision": "",
                "reason": ""
            }}
        )
        print(f"♻️ Cleared {update_result.modified_count} docs in '{collection_name}'.")
        print("✅ Cleanup complete.")
    except Exception as e:
        print("❌ Error during cleanup:", e)

# ===============================
# 🏁 TEST RUN
# ===============================
if __name__ == "__main__":
    print(f"Connected to DB: {db_name}")
    print(f"Raw news collection: {collection_name}")
    reset_testing_data()
