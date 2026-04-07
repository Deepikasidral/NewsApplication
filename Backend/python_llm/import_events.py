import pandas as pd
from pymongo import MongoClient
from datetime import datetime
import os
from dotenv import load_dotenv

# Load environment variables
load_dotenv(dotenv_path="../.env")

MONGO_URI = os.getenv("MONGO_URI")
DB_NAME = os.getenv("DB_NAME")

# Connect to MongoDB
client = MongoClient(MONGO_URI)
db = client[DB_NAME]
events_collection = db["Event"]

# Read Excel file
excel_file = "market_events_apr_may_2026.xlsx"
df = pd.read_excel(excel_file)

print(f"Found {len(df)} events in Excel file")

# Clear existing events (optional - comment out if you want to keep old data)
# events_collection.delete_many({})
# print("Cleared existing events")

# Convert and insert events
inserted_count = 0
for _, row in df.iterrows():
    event_doc = {
        "title": row["title"],
        "description": row["description"],
        "date": datetime.strptime(row["date"], "%Y-%m-%d"),
        "type": row["type"],
        "tags": "",  # Empty tags field
        "headline": "",  # Empty headline field
        "createdAt": datetime.now(),
        "updatedAt": datetime.now()
    }
    
    try:
        events_collection.insert_one(event_doc)
        inserted_count += 1
        print(f"Inserted: {row['title']}")
    except Exception as e:
        print(f"Failed to insert {row['title']}: {e}")

print(f"\nSuccessfully inserted {inserted_count} events into MongoDB")
