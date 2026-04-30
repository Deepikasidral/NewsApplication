import os
import sys
import json
import requests
from datetime import datetime, timedelta, timezone
from urllib.parse import quote
from dotenv import load_dotenv
from pymongo import MongoClient
from openai import OpenAI
from pytz import timezone as pytz_timezone
import hashlib
from rapidfuzz import process, fuzz

import firebase_admin
from firebase_admin import credentials, messaging

import re

IST = pytz_timezone("Asia/Kolkata")


BASE_DIR = os.path.dirname(os.path.abspath(__file__))
os.chdir(BASE_DIR)

COMPANIES_CACHE = None
COMPANY_LOOKUP_CACHE = None



# ================================
# 🔧 CONFIGURATION
# ================================
load_dotenv()

mongo_uri = os.getenv("MONGO_URI")
db_name = os.getenv("DB_NAME")

client = MongoClient(mongo_uri)
db = client[db_name]

filtered_news = db["filtered_news"]
filtered_news.create_index(
    "content_hash",
    unique=True,
    partialFilterExpression={
        "content_hash": {"$exists": True}
    }
)


companies_col = db["Company_data"]



openai_client = OpenAI(
    api_key=os.getenv("OPENAI_API_KEY")
)




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

def load_companies_cache():
    global COMPANIES_CACHE, COMPANY_LOOKUP_CACHE

    if COMPANIES_CACHE is None:
        COMPANIES_CACHE = list(
            companies_col.find({}, {"SYMBOL": 1, "NAME OF COMPANY": 1, "_id": 0})
        )
        COMPANY_LOOKUP_CACHE = build_company_lookup(COMPANIES_CACHE)

    return COMPANY_LOOKUP_CACHE


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

def compute_news_hash(article):
    text = (
        (article.get("Headline", "") + " " + article.get("story", ""))
        .lower()
        .strip()
    )
    text = re.sub(r"\s+", " ", text)
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


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
        response = openai_client.chat.completions.create(
            model="gpt-4o-mini",
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_input},
            ],
            temperature=0.0,
        )

        return response.choices[0].message.content.strip()

    except Exception as e:
        print("❌ OpenAI Error:", e)
        return None

# ================================
# ⚙️ notification CALL HELPER
# ================================

def send_push_notification(article, agent2, agent3):
    title = "High Impact Market News"

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

# def send_push_notification(article, agent2, agent3):
#     title = "🚨 High Impact Market News"
#     body = (
#         f"{article.get('Headline')}\n"
#         f"Sentiment: {agent3['sentiment']} | Impact: {agent3['impact']}"
#     )

#     # 🔥 ONLY USERS WHO ENABLED NOTIFICATIONS
#     users = db["Users"].find(
#         {
#             "notifications": True,
#             "fcmToken": {"$exists": True, "$ne": ""}
#         },
#         {"fcmToken": 1}
#     )

#     tokens = [u["fcmToken"] for u in users]

#     if not tokens:
#         print("🔕 No users eligible for notifications")
#         return

#     message = messaging.MulticastMessage(
#         notification=messaging.Notification(
#             title=title,
#             body=body,
#         ),
#         data={
#             "FileName": article.get("FileName", ""),
#             "headline": article.get("Headline", ""),
#             "sentiment": agent3["sentiment"],
#             "impact": agent3["impact"]
#         },
#         tokens=tokens
#     )

#     try:
#         response = messaging.send_multicast(message)
#         print(f"🔔 Sent to {response.success_count} users")
#     except Exception as e:
#         print("❌ Push notification failed:", e)

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

agent2a_prompt = """
You are a financial entity extraction agent.

TASK:
Read and understand the news and classify as either STOCK or COMMODITY news.


### ALLOWED COMMODITIES ###

You MUST choose commodities ONLY from this list:

- GOLD
- SILVER
- CRUDE OIL
- NATURAL GAS
- COPPER
- ALUMINIUM
- ZINC
- LEAD
- NICKEL

Do NOT output any commodity outside this list.
Do NOT output variations like "Brent", "WTI", "Gold Futures", etc.
Use EXACT spelling from list above.

---

### ✅ ALLOWED SECTORS ###


If multiple companies are involved, you MUST choose ONLY ONE sector from this list:

- Nifty Bank
- Nifty IT
- Nifty Pharma
- Nifty FMCG
- Nifty Auto
- Nifty Metal
- Nifty Energy
- Nifty Financial Services
- Nifty Realty
- Nifty Oil & Gas

⚠️ Do NOT create new sectors
⚠️ Do NOT modify sector names
⚠️ Use EXACT spelling

---


### CLASSIFICATION RULE ###


IF COMMODITY NEWS:
- Identify directly impacted commodity
- Mention maximum 2 commodities
- Only choose from allowed commodities list
- Do NOT include companies

IF STOCK NEWS:
- Extract ONLY companies DIRECTLY involved in MAIN EVENT

---

### INCLUDE a company ONLY IF:
The company is:
- Taking an action
- Being directly impacted
- Primary subject of event
- Official participant in transaction

⚠️ SPECIAL RULE FOR BANKS:
- Always extract individual bank names (HDFC Bank, ICICI Bank, SBI, etc.)
- Do NOT use "Nifty Bank" sector unless more than 6 banks are mentioned
- Banks are companies, not sectors

---

### DO NOT INCLUDE companies that are:
- Competitors or comparison references
- Analyst mentions
- Historical or contextual mentions
- Industry discussion only
- Opinion quotes without involvement

---

###  PRIORITY RULE
If article focuses on ONE company → return only that company

If SAME event involves multiple companies → return all (up to 6 companies)

If MORE THAN 6 relevant companies → return:
- sector from allowed list
- companies MUST be empty

---

### STRICT RULES
- Do NOT infer companies
- Do NOT normalize company names
- Return EXACT text names
- If sector selected → companies must be empty
- If commodity news → companies must be empty

---

### OUTPUT JSON ONLY
{
  "news_type": "stock" or "commodity",
  "companies": [],
  "sector": "",
  "commodities": []
}
"""


agent2_prompt = """
You are Agent 2, the Summarization & Sector Classification Agent for Rupee Letter (India).

### TASKS
1. Read the article carefully.
2. Write a **40–60 word investor-friendly summary**.
3. Assign sector and flags based on the rules below.
4. Use ONLY the validated company list provided. Do NOT add, remove, infer, or modify companies.

---

### 📝 SUMMARIZATION RULES
- Neutral, factual, journalistic tone
- Focus only on financial, strategic, policy, or market-impacting information
- Exclude source tags, fillers, and quotes
- Length strictly between 40–60 words (never exceed 70)

---

### 🏢 COMPANY HANDLING RULES (IMPORTANT)
- A validated list of companies will be provided separately
- Do NOT identify companies yourself
- Do NOT infer or guess companies
- Do NOT change company names
- If the list is empty, treat the article as non-company-specific

---

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

If IPO-related:
- DO NOT assign any other sector
- Ignore company presence

---

#### 📌 STANDARD SECTOR RULES (apply only if NOT IPO)
Choose ONE dominant sector ONLY if at least one validated Indian listed company is present:
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

#### 📉 FALLBACK (no validated company present)
If **no validated Indian listed company** is provided:
- sector = "General Market" OR "Macro / Economy" (choose best fit)

---

### 🌍 GLOBAL FLAG RULE
Set `"global": true` ONLY if:
- The article primarily relates to **countries or markets outside India**
- Examples: US Fed, China economy, Europe inflation, foreign central banks

Otherwise:
- `"global": false`

---

### 🪙 COMMODITIES FLAG RULE
Set `"commodities": true` ONLY if:
- The article is mainly about **gold, silver, crude oil, natural gas, bullion, or commodity outlook**
- Includes domestic or global commodity movement

Otherwise:
- `"commodities": false`

---

### ❗ FINAL PRIORITY ORDER
1. IPO news → sector = "IPO"
2. Global commodity news → global = true, commodities = true
3. India-focused commodity news → commodities = true, global = false
4. Company-specific news → both flags = false

---

### 🧾 OUTPUT FORMAT (STRICT JSON ONLY)
{
  "summary": "<40–60 word summary>",
  "sector": "<IPO | sector name | General Market | Macro / Economy>",
  "global": true or false,
  "commodities": true or false
}

Return JSON only. No commentary.
"""



def normalize_llm_name(name):
    name = name.lower()
    name = re.sub(r"[^\w\s]", "", name)  # remove dots, commas
    name = re.sub(r"\b(bank|ltd|limited)\b", "", name)
    return name.strip()

def normalize_company_name(name: str) -> str:
    name = name.lower()
    name = re.sub(r"\blimited\b|\bltd\b|\bplc\b|\bcorp\b|\bcorporation\b", "", name)
    name = re.sub(r"\s+", " ", name)
    return name.strip()

def build_company_lookup(companies_data):
    lookup = {}
    for c in companies_data:
        name = normalize_company_name(c["NAME OF COMPANY"])
        lookup[name] = c["NAME OF COMPANY"]

        # Also add symbol
        if c.get("SYMBOL"):
            lookup[c["SYMBOL"].lower()] = c["NAME OF COMPANY"]

    return lookup

def match_llm_companies_to_db(llm_companies, company_lookup, threshold=85):
    matched = set()

    for llm_name in llm_companies:
        key = normalize_llm_name(llm_name)


        best = process.extractOne(
            key,
            company_lookup.keys(),
            scorer=fuzz.token_sort_ratio
        )

        if best and best[1] >= threshold:
            matched.add(company_lookup[best[0]])
            print(f"✅ Matched: '{llm_name}' → '{company_lookup[best[0]]}' ({best[1]})")
        else:
            print(f"❌ No DB match for: '{llm_name}'")

    return list(matched)


def process_agent2a(article):
    text = f"Title: {article.get('Headline','')}\n\nContent:\n{article.get('story','')}"
    result = get_llm_response(agent2a_prompt, text)

    if not result:
        return None

    try:
        return json.loads(result)
    except:
        print("⚠️ Agent2A JSON error")
        return None



def process_agent2(article):
    text = f"Title: {article.get('Headline','')}\n\nContent:\n{article.get('story','')}"

    # 2️⃣ Agent 2A → raw company mentions
    agent2a_data = process_agent2a(article)

    if not agent2a_data:
        return None

    news_type = agent2a_data.get("news_type")
    llm_companies = agent2a_data.get("companies", [])
    llm_sector = agent2a_data.get("sector", "")
    llm_commodities = agent2a_data.get("commodities", [])

    print(f"\n🧠 LLM extracted companies: {llm_companies}")

    # 3️⃣ Build lookup + fuzzy match
    company_lookup = load_companies_cache()
    validated_companies = match_llm_companies_to_db(llm_companies, company_lookup)

    final_sector = ""
    final_commodities = []
    final_companies = validated_companies

    if news_type == "commodity":
        final_companies = []
        final_commodities = llm_commodities
        final_sector = ""

    elif news_type == "stock":
        final_commodities = []

        if len(validated_companies) >= 6:
            final_sector = llm_sector if llm_sector else ""
            final_companies = []

        else:
            final_sector = ""

    # 4️⃣ Call Agent 2 for summary & sector
    llm_input = f"""
    Article:
    {text}

    Validated companies:
    {final_companies if final_companies else "None"}

    Sector override:
    {final_sector if final_sector else "None"}

    Commodities:
    {final_commodities if final_commodities else "None"}
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

    # 5️⃣ FORCE companies to validated list only
    agent2_data["companies"] = final_companies
    agent2_data["sector_override"] = final_sector
    agent2_data["commodities_override"] = final_commodities

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

def remove_pti_references(text):
    if not text:
        return text

    # Remove (PTI)
    text = re.sub(r"\(PTI\)", "", text, flags=re.IGNORECASE)

    # Remove sentences containing PTI
    text = re.sub(r"[^.]*\bPTI\b[^.]*\.", "", text, flags=re.IGNORECASE)

    # Remove "Press Trust of India"
    text = re.sub(r"Press Trust of India", "", text, flags=re.IGNORECASE)

    # 🔥 Remove trailing PTI bureau codes like: PTI NKD TRB TRB
    text = re.sub(r"\bPTI\b[\sA-Z]{0,20}$", "", text.strip())

    # 🔥 Remove standalone 2-4 letter uppercase codes at end
    text = re.sub(r"\b[A-Z]{2,4}\b(?:\s+\b[A-Z]{2,4}\b)*$", "", text.strip())

    # Clean extra whitespace
    text = re.sub(r"\s+", " ", text).strip()

    return text



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



        content_hash = compute_news_hash(article)
        clean_headline = remove_pti_references(article.get("Headline", ""))
        clean_story = remove_pti_references(article.get("story", ""))

        final_doc = {
            **article,
            "Headline": clean_headline,
            "story": clean_story,
            "content_hash": content_hash,

            "decision": agent1["decision"],
            "filter_reason": agent1.get("reason"),

            "summary": agent2["summary"],

            # ⭐ Rupee Letter Sector
            "sector": agent2["sector"],

            # ⭐ Trading / Market Sector
            "sector_market": agent2.get("sector_override"),

            "companies": agent2["companies"],

            "global": agent2["global"],

            # ⭐ Commodity Boolean Flag
            "commodities": agent2["commodities"],

            # ⭐ Actual Commodity Names
            "commodities_market": agent2.get("commodities_override"),

            "sentiment": agent3["sentiment"],
            "impact": agent3["impact"],
            "impact_rationale": agent3.get("rationale"),

            "ingested_at": datetime.now(timezone.utc)
        }


        try:
            # Check if already exists by FileName or content_hash
            existing = filtered_news.find_one({
                "$or": [
                    {"FileName": file_name},
                    {"content_hash": content_hash}
                ]
            })
            
            if existing:
                print("⏩ Duplicate detected - skipping")
                continue

            result = filtered_news.update_one(
                {"content_hash": content_hash},
                {"$setOnInsert": final_doc},
                upsert=True
            )

            if result.upserted_id:
                stored_count += 1
                print("✅ Stored new article")

                if notify:
                    print(f"🔔 Sending notification for: {article.get('Headline','')[:60]}")
                    send_push_notification(article, agent2, agent3)
            else:
                print("⏩ Duplicate skipped (same content)")
        except Exception as e:
            print(f"❌ Insert failed: {e}")


    print(f"\n🎯 Pipeline complete: Fetched={fetched_count}, Filtered={filtered_count}, Stored={stored_count}")

    if stored_count == 0 and fetched_count > 0:
        save_last_run_time(datetime.now(IST))

# ================================
# 🏁 ENTRY POINT
# ================================
if __name__ == "__main__":
    run_pipeline()