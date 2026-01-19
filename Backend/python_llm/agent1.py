import os
import sys
import json
import requests
from datetime import datetime, timedelta, timezone
from urllib.parse import quote
from dotenv import load_dotenv
from pymongo import MongoClient
from openai import AzureOpenAI
from pytz import timezone as pytz_timezone

import firebase_admin
from firebase_admin import credentials, messaging

import re

IST = pytz_timezone("Asia/Kolkata")





BASE_DIR = os.path.dirname(os.path.abspath(__file__))
os.chdir(BASE_DIR)


# ================================
# 🔧 CONFIGURATION
# ================================
load_dotenv(dotenv_path="../.env")

mongo_uri = os.getenv("MONGO_URI")
db_name = os.getenv("DB_NAME")

client = MongoClient(mongo_uri)
db = client[db_name]

filtered_news = db["filtered_news"]
companies_col = db["Company_data"]

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
            last_time_str = f.read().strip()
            last_time = datetime.fromisoformat(last_time_str)
            if last_time.tzinfo is None:
                last_time = last_time.replace(tzinfo=IST)
            return last_time.astimezone(IST)
    return datetime.now(IST) - timedelta(minutes=30)

def save_last_run_time(dt):
    with open(LAST_RUN_FILE, "w") as f:
        f.write(dt.isoformat())

# ================================
# 🌐 FETCH PTI NEWS
# ================================


def fetch_pti_news():
    start_time = get_last_run_time()
    end_time = datetime.now(IST)

    from_time = quote(start_time.strftime("%Y/%m/%d %H:%M:%S"))
    to_time = quote(end_time.strftime("%Y/%m/%d %H:%M:%S"))

    url = (
        "https://editorial.pti.in/ptiapi/webservice1.asmx/JsonFile1"
        f"?centercode=17102025001RL"
        f"&FromTime={from_time}"
        f"&EndTime={to_time}"
    )

    print(f"⏱ Fetching PTI news (IST): {start_time} → {end_time}")

    try:
        headers = {
            "User-Agent": "Mozilla/5.0",
            "Accept": "application/json,text/plain,*/*",
            "Connection": "keep-alive",
        }
        response = requests.get(url, headers=headers, timeout=30)
    except Exception as e:
        print("❌ PTI request failed:", e)
        return []

    if response.status_code != 200:
        print("❌ PTI API HTTP error:", response.status_code)
        print(response.text[:300])
        return []

    try:
        data = response.json()
    except ValueError:
        print("❌ PTI API returned NON-JSON response")
        print("Response preview:")
        print(response.text[:300])
        return []

    if isinstance(data, dict):
        articles = data.get("Table", [])
    elif isinstance(data, list):
        articles = data
    else:
        articles = []

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

# def send_push_notification(article, agent2, agent3):
#     title = "🚨 High Impact Market News"

#     body = (
#         f"{article.get('Headline')}\n"
#         f"Sentiment: {agent3['sentiment']} | Impact: {agent3['impact']}"
#     )

#     message = messaging.Message(
#         notification=messaging.Notification(
#             title=title,
#             body=body,
#         ),
#        data={
#             "FileName": article.get("FileName", ""),
#             "headline": article.get("Headline", ""),
#             "sentiment": agent3["sentiment"],
#             "impact": agent3["impact"]
#         },

#         topic="market_alerts"
#     )

#     try:
#         messaging.send(message)
#         print("🔔 Push notification sent")
#     except Exception as e:
#         print("❌ Push notification failed:", e)

def send_push_notification(article, agent2, agent3):
    title = "🚨 High Impact Market News"
    body = (
        f"{article.get('Headline')}\n"
        f"Sentiment: {agent3['sentiment']} | Impact: {agent3['impact']}"
    )

    # 🔥 ONLY USERS WHO ENABLED NOTIFICATIONS
    users = db["Users"].find(
        {
            "notifications": True,
            "fcmToken": {"$exists": True, "$ne": ""}
        },
        {"fcmToken": 1}
    )

    tokens = [u["fcmToken"] for u in users]

    if not tokens:
        print("🔕 No users eligible for notifications")
        return

    message = messaging.MulticastMessage(
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
        tokens=tokens
    )

    try:
        response = messaging.send_multicast(message)
        print(f"🔔 Sent to {response.success_count} users")
    except Exception as e:
        print("❌ Push notification failed:", e)

# ================================
# 🧠 AGENT 1: NEWS FILTER
# ================================
agent1_prompt = """

You are Agent 1, a financial news filter for a news platform.
Your goal is to decide whether an incoming news article is USEFUL for investors, traders, or finance readers, especially in the short term.

You must classify the article strictly into one of:
- "keep" - The article contains market-relevant, actionable, or insightful information.
- "discard" - The article is trivial, repetitive, or irrelevant to stock markets or investing.

### KEEP if the article includes:
1. Company or stock market developments
   - Quarterly results, earnings, M&A, IPOs, major deals, partnerships, board changes, rating outlooks.
2. Market trends
   - Sensex/Nifty movement, FII/DII flows, sectoral or global market cues.
3. Economic or policy updates
   - RBI decisions, SEBI guidelines, trade policies, macro indicators (GDP, inflation, exports, etc.).
4. Major corporate or startup news impacting valuations or investor sentiment.
5. Global financial events affecting India’s markets (US Fed, crude oil, currency moves).

### DISCARD if:
- It’s a short “📰 NEWSALERT” or headline-only story.
- It lists prices/rates without context (e.g., bullion, pepper, copra, exchange rates, futures tickers).
- It’s a schedule, data dump, or table (RBI operations, business schedules, etc.).
- It’s duplicate or repetitive of a similar headline.
- It’s under 80 words with no analytical or market impact content.
- Any news that might appear useful but has no Direct impact on the short term price of the relevant stock or an index

Return a short, structured JSON output only:
{
  "decision": "keep" or "discard",
  "reason": "brief reason (10-20 words max)"
}
Do not add any extra commentary.
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

STOP_WORDS = {
    "limited", "ltd", "private", "bank", "group",
    "industries", "company", "corp", "corporation"
}

def prefilter_companies(article_text, companies_data, max_candidates=20):
    text = article_text.lower()
    candidates = []

    for c in companies_data:
        name = c.get("NAME OF COMPANY", "")
        symbol = c.get("SYMBOL", "")

        # 1️⃣ SYMBOL match (word-boundary safe)
        if symbol:
            pattern = rf"\b{re.escape(symbol.lower())}\b"
            if re.search(pattern, text):
                candidates.append(c)
                continue

        # 2️⃣ COMPANY NAME token match (fallback)
        tokens = [
            t.lower()
            for t in re.split(r"\W+", name)
            if len(t) > 3 and t.lower() not in STOP_WORDS
        ]

        for token in tokens:
            pattern = rf"\b{re.escape(token)}\b"
            if re.search(pattern, text):
                candidates.append(c)
                break

        if len(candidates) >= max_candidates:
            break

    return candidates



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
-ONLY If no company is mentioned:
 Even if the company is related to commodities, and is found in NSE–BSE database DO NOT tag it as commodities.
	Segregate the news as - global or commodities

---
### 🔒 STRICT NAME OUTPUT RULE (MANDATORY)
- You MUST return company names EXACTLY as they appear in the provided company list.
- Do NOT shorten names.
- Do NOT remove words like "Limited", "Ltd", "Bank", etc.
- Do NOT change capitalization.
- If unsure, DO NOT include the company.


### 🏷️ SECTOR ASSIGNMENT RULES

#### 🔥 HIGHEST PRIORITY — IPO
Set:
- `"sector": "IPO"`

ONLY if the article is **primarily about an Initial Public Offering**, including:
- IPO filing (DRHP, RHP)
- IPO launch or announcement
- Issue size, price band, lot size
- Subscription status, anchor investors
- IPO listing, debut, GMP, allotment, grey market premium

If the article is IPO-related, **DO NOT assign any other sector**, even if companies are mentioned.

---

#### 📌 STANDARD SECTOR RULES (apply only if NOT IPO)
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

---

#### 📉 FALLBACK (no listed company mentioned)
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

### ❗ IMPORTANT PRIORITY LOGIC (FINAL ORDER)
1. IPO news → `sector = "IPO"`
2. Global commodity news → `global = true`, `commodities = true`
3. India-focused commodity news → `commodities = true`, `global = false`
4. Company-specific news → both flags = false

---

### 🧾 OUTPUT FORMAT (STRICT JSON ONLY)
{
  "summary": "<40–60 word summary>",
  "companies": [<list of matched company names>],
  "sector": "<IPO | sector name | General Market | Macro / Economy>",
  "global": true or false,
  "commodities": true or false
}

Return JSON only. No commentary.
"""
def normalize_company_name(name: str) -> str:
    name = name.lower()
    name = re.sub(r"\blimited\b|\bltd\b|\bplc\b|\bcorp\b|\bcorporation\b", "", name)
    name = re.sub(r"\s+", " ", name)
    return name.strip()


def process_agent2(article):
    text = f"Title: {article.get('Headline','')}\n\nContent:\n{article.get('story','')}"

    # 1️⃣ Fetch all companies (same as before)
    companies_data = list(
        companies_col.find({}, {"SYMBOL": 1, "NAME OF COMPANY": 1, "_id": 0})
    )

    full_db_map = {
    normalize_company_name(c["NAME OF COMPANY"]): c["NAME OF COMPANY"]
    for c in companies_data
}


    # 2️⃣ 🔥 NEW: prefilter companies in Python
    candidate_companies = prefilter_companies(text, companies_data)

    # Safety fallback (rare)
    if not candidate_companies:
        candidate_companies = []

    # 3️⃣ Send ONLY filtered companies to LLM
    company_list_formatted = "\n".join([
        f"- Symbol: {c.get('SYMBOL')}, Name: {c.get('NAME OF COMPANY')}"
        for c in candidate_companies
    ])

    llm_input = f"""
    Article:
    {text}

    Below is Rupee Letter's official company database.
    Match companies ONLY from this list:

    {company_list_formatted}
    """

    result = get_llm_response(agent2_prompt, llm_input)
    if not result:
        return None

    try:
        agent2_data = json.loads(result)
    except json.JSONDecodeError:
        print("⚠️ Agent2 JSON error")
        print(result)
        return None

    # 4️⃣ HARD validation (anti-hallucination)
    valid_names = {
    normalize_company_name(c["NAME OF COMPANY"]): c["NAME OF COMPANY"]
    for c in candidate_companies
    }

    validated_companies = []

    for comp in agent2_data.get("companies", []):
        key = normalize_company_name(comp)

        if key in valid_names:
            validated_companies.append(valid_names[key])
            print(f"✅ Matched company: {comp} → {valid_names[key]}")

        elif key in full_db_map:
            validated_companies.append(full_db_map[key])
            print(f"🛟 Fallback DB match: {comp} → {full_db_map[key]}")

        else:
            print(f"⚠️ Removed hallucinated company: {comp}")
    agent2_data["companies"] = validated_companies

    return agent2_data

# ================================
# 🧠 AGENT 3: SENTIMENT & IMPACT
# ================================
agent3_prompt = """
You are Agent 3, the Sentiment & Impact Analyzer for Rupee Letter — India’s fast, actionable finance insights platform.

### YOUR ROLE
Analyze the summarized article and estimate:
1. **Short-term sentiment** (≈ 1 week outlook) for the mentioned company or market.
2. **Impact strength** of this news on price or sentiment STRICTLY in short term (next 2-3 days) outlook.
---
### 📊 SENTIMENT SCALE (choose one word only)
- "Very Bullish" → strong positive trigger; likely short-term upside.
- "Bullish" → moderately positive; supports price sentiment.
- "Neutral" → balanced or minimal directional bias.
- "Bearish" → moderately negative; may cause minor downside.
- "Very Bearish" → strong negative trigger; likely short-term drop.

🔹 Sentiment should reflect *market reaction within a week*, not long-term fundamentals.
---
### ⚡ IMPACT SCALE (choose one)
- "Very High" → highly influential, major event (e.g., earnings surprise, policy shift, large order, merger).
- "High" → may shift the price. (e.g., mid-sized deal, positive rating).
- "Mild" → limited reaction expected or long-term price change.
- "Negligible" → almost no effect.
---

### 🧭 RULES
- Use financial reasoning — consider profits, losses, guidance, rating changes, major orders, or regulatory actions.
- If multiple companies, infer overall sentiment.
- If macro/policy news, assess general market tone.
- Always keep output strictly factual, no hype.

---

### 🧾 OUTPUT FORMAT (STRICT JSON)
{
  "sentiment": "<Very Bullish | Bullish | Neutral | Bearish | Very Bearish>",
  "impact": "<Very High | High | Mild | Negligible>",
  "rationale": "<one short 15–25 word reasoning (for internal audit)>"
}

Return JSON only, no extra commentary.
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

def parse_pti_time(pti_time_str):
    try:
        dt = datetime.strptime(pti_time_str, "%A, %b %d, %Y %H:%M:%S")
        return dt.replace(tzinfo=IST)
    except Exception:
        return None

# ================================
# 🚀 PIPELINE RUNNER
# ================================
def run_pipeline():
    articles = fetch_pti_news()
    
    fetched_count = len(articles)
    stored_count = 0
    filtered_count = 0
    
    print(f"📊 Fetched: {fetched_count} articles")

    for article in articles:
        file_name = article.get("FileName")
        if not file_name:
            continue

        if filtered_news.find_one({"FileName": file_name}):
            print(f"⏩ Duplicate skipped: {file_name}")
            continue

        print(f"\n📰 Processing: {article.get('Headline','')[:80]}")

        agent1 = process_agent1(article)
        if not agent1 or agent1["decision"] != "keep":
            print(f"🗑 Agent1 discarded: {article.get('Headline','')[:80]}")
            filtered_count += 1
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
            **article,
            "decision": agent1["decision"],
            "filter_reason": agent1.get("reason"),
            "summary": agent2["summary"],
            "sector": agent2["sector"],
            "companies": agent2["companies"],
            "global": agent2["global"],
            "commodities": agent2["commodities"],
            "sentiment": agent3["sentiment"],
            "impact": agent3["impact"],
            "impact_rationale": agent3.get("rationale"),
            "ingested_at": datetime.now(timezone.utc)
        }

        try:
            filtered_news.insert_one(final_doc)
            stored_count += 1
            print("✅ Stored enriched PTI article")
            
            pti_time = parse_pti_time(article.get("PublishedAt", ""))
            if pti_time:
                save_last_run_time(pti_time)
        except Exception as e:
            if "duplicate key" in str(e).lower():
                print(f"⏩ Duplicate insert race condition: {file_name}")
            else:
                print(f"❌ Insert failed: {e}")

    print(f"\n🎯 Pipeline complete: Fetched={fetched_count}, Filtered={filtered_count}, Stored={stored_count}")
    
    if stored_count == 0 and fetched_count > 0:
        save_last_run_time(datetime.now(IST))

# ================================
# 🏁 ENTRY POINT
# ================================
if __name__ == "__main__":
    run_pipeline()