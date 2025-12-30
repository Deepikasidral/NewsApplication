import os
import json
import requests
from datetime import datetime, timedelta, timezone
from urllib.parse import quote
from dotenv import load_dotenv
from pymongo import MongoClient
from openai import AzureOpenAI

import firebase_admin
from firebase_admin import credentials, messaging

# ================================
# 🔧 CONFIGURATION
# ================================
load_dotenv(dotenv_path="../.env")

mongo_uri = os.getenv("MONGO_URI")
db_name = os.getenv("DB_NAME")

client = MongoClient(mongo_uri)
db = client[db_name]

filtered_news = db["filtered_news"]
companies_col = db["companies"]

azure_client = AzureOpenAI(
    api_key=os.getenv("AZURE_OPENAI_KEY"),
    azure_endpoint=os.getenv("AZURE_OPENAI_ENDPOINT"),
    api_version=os.getenv("AZURE_OPENAI_API_VERSION")
)

AZURE_DEPLOYMENT = os.getenv("AZURE_DEPLOYMENT")

# Ensure deduplication (safe to run multiple times)
filtered_news.create_index("FileName", unique=True)

FIREBASE_KEY_PATH = os.path.join(
    os.path.dirname(__file__),
    "..",
    "firebase_admin_key.json"
)


if not firebase_admin._apps:
    cred = credentials.Certificate(FIREBASE_KEY_PATH)
    firebase_admin.initialize_app(cred)

# ================================
# ⏱ TIME WINDOW HANDLING
# ================================
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
LAST_RUN_FILE = os.path.join(BASE_DIR, "last_run_time.txt")


def get_last_run_time():
    if os.path.exists(LAST_RUN_FILE):
        with open(LAST_RUN_FILE, "r") as f:
            return datetime.fromisoformat(f.read().strip())
    return datetime.now(timezone.utc)- timedelta(minutes=5)

def save_last_run_time(dt):
    with open(LAST_RUN_FILE, "w") as f:
        f.write(dt.isoformat())

# ================================
# 🌐 FETCH PTI NEWS
# ================================
def fetch_pti_news():
    start_time = get_last_run_time()
    end_time = datetime.now(timezone.utc)

    from_time = quote(start_time.strftime("%Y/%m/%d %H:%M:%S"))
    to_time = quote(end_time.strftime("%Y/%m/%d %H:%M:%S"))

    url = (
        "https://editorial.pti.in/ptiapi/webservice1.asmx/JsonFile1"
        f"?centercode=17102025001RL"
        f"&FromTime={from_time}"
        f"&EndTime={to_time}"
    )

    print(f"⏱ Fetching PTI news: {start_time} → {end_time}")

    response = requests.get(url, timeout=30)

    if response.status_code != 200:
        print("❌ PTI API Error:", response.status_code)
        print(response.text[:500])
        return []

    try:
        data = response.json()
    except ValueError:
        print("❌ PTI API returned NON-JSON response")
        print("Response preview:")
        print(response.text[:500])
        return []

    # PTI may return dict or list
    if isinstance(data, dict):
        articles = data.get("Table", [])
    elif isinstance(data, list):
        articles = data
    else:
        articles = []

    save_last_run_time(end_time)
    return articles


# ================================
# ⚙️ llm CALL HELPER
# ================================
def get_llm_response(system_prompt, user_input):
    try:
        response = azure_client.chat.completions.create(
            model=AZURE_DEPLOYMENT,  # deployment name
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_input},
            ],
            temperature=0.0,
        )
        return response.choices[0].message.content.strip()
    except Exception as e:
        print("❌ Azure OpenAI Error:", str(e))
        return None

# ================================
# ⚙️ notification CALL HELPER
# ================================

def send_push_notification(article, agent2, agent3):
    title = "🚨 High Impact Market News"

    body = (
        f"{article.get('Headline')}\n"
        f"Sentiment: {agent3['sentiment']} | Impact: {agent3['impact']}"
    )

    message = messaging.Message(
        notification=messaging.Notification(
            title=title,
            body=body,
        ),
       data={
            "FileName": article.get("FileName", ""),
            "headline": article.get("Headline", ""),
            "sentiment": agent3["sentiment"],
            "impact": agent3["impact"]
        },

        topic="market_alerts"
    )

    try:
        messaging.send(message)
        print("🔔 Push notification sent")
    except Exception as e:
        print("❌ Push notification failed:", e)


# ================================
# 🧠 AGENT 1: NEWS FILTER
# ================================
agent1_prompt = """
You are Agent 1, a Financial News Filter for Rupee Letter (India).

Your task is to decide whether a news article is useful for investors, traders, or finance readers.

### CLASSIFICATION (choose ONE only)
- "keep" → Market-relevant, actionable, or sentiment-impacting
- "discard" → Trivial, repetitive, or irrelevant to investing/markets

---

### ✅ KEEP the article ONLY if it contains:
1. **Company or stock developments**
   - Earnings, results, M&A, IPOs, deals, large orders
   - Board/management changes
   - Credit rating upgrades/downgrades

2. **Significant market trends**
   - Sensex/Nifty or sector moves ONLY IF exceptional and explained
   - FII/DII flows, sector rotation, global cues affecting India

3. **Economic or policy updates**
   - RBI, SEBI, government policy
   - GDP, inflation, interest rates, fiscal or trade decisions

4. **Major corporate or startup news**
   - Events impacting valuation or investor sentiment

5. **Global financial events**
   - Fed policy, crude oil, FX, geopolitics affecting Indian markets

---

### ❌ DISCARD the article if:
- It is headline-only or a “NEWSALERT”
- It reports prices/rates without context or explanation
- It is a schedule, table, or raw data dump
- It is duplicate or repetitive
- It is under 80 words with no clear market impact

---

### 🧾 OUTPUT FORMAT (STRICT JSON ONLY)
{
  "decision": "keep" or "discard",
  "reason": "brief reason (10–20 words)"
}

Do not add any commentary outside JSON.
"""


def process_agent1(article):
    text = f"Title: {article.get('Headline','')}\n\nContent:\n{article.get('story','')}"
    result = get_llm_response(agent1_prompt, text)
    if not result:
        return None
    return json.loads(result)

# ================================
# 🧠 AGENT 2: SUMMARY & COMPANY TAGGING
# ================================
agent2_prompt = """
You are Agent 2, the Summarization & Sector Classification Agent for Rupee Letter (India).

### TASKS
1. Read the article carefully.
2. Write a **40–60 word investor-friendly summary**.
3. Identify NSE/BSE-listed companies mentioned in the article using Rupee Letter’s database.
4. Assign sector and flags based on strict rules below.

---

### 📝 SUMMARIZATION RULES
- Neutral, factual, journalistic tone
- Focus only on financial, strategic, policy, or market-impacting information
- Exclude source tags, fillers, and quotes
- Length strictly between 40–60 words (never exceed 70)

---

### 🏢 COMPANY TAGGING RULES
- Tag ONLY companies that exist in the provided NSE–BSE database
- Match by **exact company name or symbol** (case-insensitive)
- Include only if explicitly mentioned in article text
- Do NOT infer or guess

---

### 🏷️ SECTOR ASSIGNMENT RULES
Choose ONE dominant sector ONLY if an Indian listed company is mentioned:
- Banking and Financial Services
- IT and Services Sector
- Media
- FMCG
- Pharma and Healthcare
- Automobile
- Metal and Infrastructure
- Energy and Oil & Gas
- Realty

If **no Indian listed company** is mentioned:
- sector = "General Market" OR "Macro / Economy" (choose best fit)

---

### 🌍 GLOBAL FLAG RULE
Set `"global": true` ONLY if:
- The article primarily relates to **countries or markets outside India**
- Examples: US Fed, China economy, Europe inflation, global recession, foreign central banks

Otherwise:
- `"global": false`

---

### 🪙 COMMODITIES FLAG RULE
Set `"commodities": true` ONLY if:
- The article is mainly about **gold, silver, crude oil, natural gas, bullion, commodities prices, or commodity outlook**
- Includes global or domestic commodity movement

Otherwise:
- `"commodities": false`

---

### ❗ IMPORTANT PRIORITY LOGIC
- Global commodity news → `global = true` AND `commodities = true`
- India-focused commodity news → `commodities = true`, `global = false`
- Company-specific news → both flags = false

---

### 🧾 OUTPUT FORMAT (STRICT JSON ONLY)
{
  "summary": "<40–60 word summary>",
  "companies": [<list of matched company names>],
  "sector": "<sector name or fallback>",
  "global": true or false,
  "commodities": true or false
}

Return JSON only. No commentary.
"""

def process_agent2(article):
    text = f"Title: {article.get('Headline','')}\n\nContent:\n{article.get('story','')}"

    companies_data = list(
        companies_col.find({}, {"SYMBOL": 1, "NAME OF COMPANY": 1, "_id": 0})
    )

    llm_input = f"""
    Article:
    {text}

    Company database:
    {json.dumps(companies_data, ensure_ascii=False)}
    """

    result = get_llm_response(agent2_prompt, llm_input)
    if not result:
        return None
    return json.loads(result)

# ================================
# 🧠 AGENT 3: SENTIMENT & IMPACT
# ================================
agent3_prompt = """
You are Agent 3, the Sentiment & Impact Analyzer for Rupee Letter (India).

### TASKS
Based on the summarized article, determine:
1. Short-term sentiment (≈ 1-week market reaction)
2. Impact strength on price or investor sentiment

---

### 📊 SENTIMENT OPTIONS (choose ONE)
- Very Bullish
- Bullish
- Neutral
- Bearish
- Very Bearish

(Assess short-term reaction, not long-term fundamentals)

---

### ⚡ IMPACT OPTIONS (choose ONE)
- Very High → major trigger (earnings surprise, policy shift, merger, large order)
- High → notable but limited-scale event
- Mild → small or temporary reaction
- Negligible → minimal market effect

---

### RULES
- Base decisions on financial logic (earnings, guidance, orders, ratings, regulation)
- If multiple companies, infer overall sentiment
- For macro news, assess broad market tone
- Avoid hype or opinionated language

---

### 🧾 OUTPUT FORMAT (STRICT JSON ONLY)
{
  "sentiment": "<Very Bullish | Bullish | Neutral | Bearish | Very Bearish>",
  "impact": "<Very High | High | Mild | Negligible>"
}

Return JSON only. No commentary.
"""

def process_agent3(agent2_data):
    input_text = (
        f"Summary: {agent2_data['summary']}\n"
        f"Sector: {agent2_data['sector']}\n"
        f"Companies: {', '.join(agent2_data.get('companies', []))}"
    )

    result = get_llm_response(agent3_prompt, input_text)
    if not result:
        return None
    return json.loads(result)

# ================================
# 🚀 PIPELINE RUNNER
# ================================
def run_pipeline():
    articles = fetch_pti_news()

    for article in articles:
        file_name = article.get("FileName")
        if not file_name:
            continue

        # Skip if already processed
        if filtered_news.find_one({"FileName": file_name}):
            continue

        print(f"\n📰 Processing: {article.get('Headline','')[:80]}")

        agent1 = process_agent1(article)
        if not agent1 or agent1["decision"] != "keep":
            continue

        agent2 = process_agent2(article)
        if not agent2:
            continue

        agent3 = process_agent3(agent2)
        if not agent3:
            continue

        notify = (
            agent3["impact"] == "Very High" or
            agent3["sentiment"] in ["Very Bullish", "Very Bearish"]
        )

        if notify:
            send_push_notification(article, agent2, agent3)


        final_doc = {
            **article,  # ALL PTI API FIELDS

            # Agent 1
            "decision": agent1["decision"],
            "filter_reason": agent1.get("reason"),

            # Agent 2
          
            "summary": agent2["summary"],
            "sector": agent2["sector"],
            "companies": agent2["companies"],
            "global": agent2["global"],
            "commodities": agent2["commodities"],


            # Agent 3
            "sentiment": agent3["sentiment"],
            "impact": agent3["impact"],

            # System
            "ingested_at": datetime.now(timezone.utc)

        }

        filtered_news.insert_one(final_doc)
        print("✅ Stored enriched PTI article")

    print("\n🎯 Pipeline complete.")

# ================================
# 🏁 ENTRY POINT
# ================================
if __name__ == "__main__":
    run_pipeline()
