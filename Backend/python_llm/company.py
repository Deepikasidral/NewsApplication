import pandas as pd
from pymongo import MongoClient

# ---------------- CONFIG ----------------
MONGO_URI = "mongodb+srv://deepikasidral:deep@cluster0.dq1txpn.mongodb.net/New_application?retryWrites=true&w=majority&appName=Cluster0"
DB_NAME = "New_application"          # 🔴 CHANGE THIS
COLLECTION_NAME = "Company_data"
CSV_FILE_PATH = "New_Company_Data.csv"  # 🔴 CHANGE PATH IF NEEDED
# ---------------------------------------

def main():
    client = MongoClient(MONGO_URI)
    db = client[DB_NAME]
    collection = db[COLLECTION_NAME]

    # DELETE ALL OLD RECORDS
    result = collection.delete_many({})
    print(f"🗑️ Deleted {result.deleted_count} existing records")

    # READ CSV
    df = pd.read_csv(CSV_FILE_PATH)

    documents = []

    for _, row in df.iterrows():
        doc = {
            "SYMBOL": str(row["SYMBOL"]).strip(),
            "NAME OF COMPANY": str(row["NAME OF COMPANY"]).strip(),
            "ISIN NUMBER": str(row["ISIN NUMBER"]).strip()  # ✅ FIXED
        }
        documents.append(doc)

    if documents:
        collection.insert_many(documents)
        print(f"✅ Inserted {len(documents)} new records")

    print("🎉 Company_data collection fully replaced")

if __name__ == "__main__":
    main()

