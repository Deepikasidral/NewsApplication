# import os
# import json
# from datetime import datetime
# from dotenv import load_dotenv
# from pymongo import MongoClient
# from groq import Groq

# # ================================
# # 🔧 CONFIGURATION
# # ================================
# load_dotenv(dotenv_path="../.env")

# mongo_uri = os.getenv("MONGO_URI")
# db_name = os.getenv("DB_NAME")
# collection_name = os.getenv("COLLECTION_NAME")
# groq_api_key = os.getenv("GROQ_API_KEY")

# # MongoDB setup
# client = MongoClient(mongo_uri)
# db = client[db_name]
# all_news = db[collection_name]
# filtered_news = db["filtered_news"]

# # Groq setup
# groq_client = Groq(api_key=groq_api_key)

# # ================================
# # 🧠 SYSTEM PROMPT
# # ================================
# agent1_prompt = """
# You are Agent 1, a financial news filter for Rupee Letter — India’s fast, simple finance news platform.
# Your goal is to decide whether an incoming news article is USEFUL for investors, traders, or finance readers.

# You must classify the article strictly into one of:
# - "keep" → The article contains market-relevant, actionable, or insightful information.
# - "discard" → The article is trivial, repetitive, or irrelevant to stock markets or investing.

# ### KEEP if the article includes:
# 1. Company or stock market developments
#    - Quarterly results, earnings, M&A, IPOs, major deals, partnerships, board changes, rating outlooks.
# 2. Market trends
#    - Sensex/Nifty movement, FII/DII flows, sectoral or global market cues.
# 3. Economic or policy updates
#    - RBI decisions, SEBI guidelines, trade policies, macro indicators (GDP, inflation, exports, etc.).
# 4. Major corporate or startup news impacting valuations or investor sentiment.
# 5. Global financial events affecting India’s markets (US Fed, crude oil, currency moves).

# ### DISCARD if:
# - It’s a short “📰 NEWSALERT” or headline-only story.
# - It lists prices/rates without context (e.g., bullion, pepper, copra, exchange rates, futures tickers).
# - It’s a schedule, data dump, or table (RBI operations, business schedules, etc.).
# - It’s duplicate or repetitive of a similar headline.
# - It’s under 80 words with no analytical or market impact content.

# Return a short, structured JSON output only:
# {
#   "decision": "keep" or "discard",
#   "reason": "brief reason (10-20 words max)"
# }
# Do not add any extra commentary.
# """

# # ================================
# # ⚙️ HELPER: Call Groq API
# # ================================
# def get_groq_response(prompt_text):
#     try:
#         response = groq_client.chat.completions.create(
#             model="llama-3.1-8b-instant",
#             messages=[
#                 {"role": "system", "content": agent1_prompt},
#                 {"role": "user", "content": prompt_text},
#             ],
#             temperature=0.0,
#         )
#         return response.choices[0].message.content.strip()
#     except Exception as e:
#         print("❌ Groq API Error:", str(e))
#         return None

# # ================================
# # 🚀 PROCESS SINGLE ARTICLE
# # ================================
# def process_article(article):
#     title = article.get("Headline", "") or article.get("title", "")
#     content = article.get("story", "") or article.get("content", "")
#     text = f"Title: {title}\n\nContent:\n{content}"

#     result = get_groq_response(text)
#     if not result:
#         return None

#     try:
#         decision_data = json.loads(result)
#     except json.JSONDecodeError:
#         print(f"⚠️ JSON parse error for article: {title}")
#         print("Raw response:", result)
#         return None

#     decision = decision_data.get("decision", "").lower()

#     # Save in DB
#     all_news.update_one(
#         {"_id": article["_id"]},
#         {"$set": {
#             "processed_by_agent1": True,
#             "decision": decision,
#             "reason": decision_data.get("reason")
#         }},
#     )

#     if decision == "keep":
#         article.update({
#             "decision": "keep",
#             "reason": decision_data.get("reason"),
#             "processed_at": datetime.utcnow(),
#         })
#         filtered_news.insert_one(article)
#         print(f"✅ Kept: {title}")
#     else:
#         print(f"🗑️ Discarded: {title}")

#     return decision_data

# # ================================
# # 🧩 RUN BATCH
# # ================================
# def run_agent1_batch(limit=50):
#     unprocessed = all_news.find({"processed_by_agent1": {"$exists": False}}).limit(limit)
#     count = 0
#     for article in unprocessed:
#         print(f"\n📰 Processing: {article.get('Headline', article.get('title', 'Untitled'))[:80]}...")
#         output = process_article(article)
#         print("🔎 Decision:", output)
#         count += 1
#         if count == 20:  # remove this line if you want full batch
#             break
#     print(f"\n🎯 Batch complete. Processed {count} articles.")

# # ================================
# # 🏁 ENTRY POINT
# # ================================
# if __name__ == "__main__":
#     run_agent1_batch()
import os
import json
from datetime import datetime
from dotenv import load_dotenv
from pymongo import MongoClient
from groq import Groq

# ================================
# 🔧 CONFIGURATION
# ================================
load_dotenv(dotenv_path="../.env")

mongo_uri = os.getenv("MONGO_URI")
db_name = os.getenv("DB_NAME")
collection_name = os.getenv("COLLECTION_NAME")
groq_api_key = os.getenv("GROQ_API_KEY")

# MongoDB setup
client = MongoClient(mongo_uri)
db = client[db_name]
all_news = db[collection_name]
filtered_news = db["filtered_news"]
companies_col = db["companies"]  # company database with {name, symbol, sector}

# Groq setup
groq_client = Groq(api_key=groq_api_key)

# ================================
# 🧠 AGENT 1: NEWS FILTER
# ================================
agent1_prompt = """You are Agent 1, the News Filter for Rupee Letter — India’s fast, simple finance insights app.

Your job is to decide if a news article is **useful** for investors or traders and worth showing on the app feed.

Return only:
- "keep" → if it contains **specific, actionable, or significant** market or company impact.
- "discard" → if it’s routine, repetitive, or trivial.

---

### ✅ KEEP only if the article covers:
1. **Company-specific impact**
   - Earnings, M&A, orders, partnerships, IPOs, leadership changes, rating changes.
2. **Policy / regulatory moves**
   - RBI, SEBI, government, fiscal, or tax announcements that influence markets.
3. **Exceptional market moves**
   - Sharp rallies/crashes (Sensex/Nifty move ≥ 1.5%), sector rotations, FII inflows/outflows, global shock events.
4. **Macro or global developments**
   - Fed, oil, currency, or geopolitical events that directly affect Indian markets.

---

### ❌ DISCARD if:
- It’s a **routine daily market wrap** (e.g., “Sensex up 300 pts, Nifty ends higher for 3rd day”).
- It contains **no new trigger** or explanation beyond market direction.
- It’s a **commodity rate**, **currency rate**, or **price table**.
- It’s a **short flash** (NEWSALERT, schedule, RBI operations, etc.).
- It’s **duplicative or purely statistical** (e.g., “Gold up 0.2%”, “Rupee rises 3 paise”).
- Word count < 80 words.

---

### 🔍 Guidance for “Market Movement” stories
Keep **only** if:
- It mentions *cause or driver* of the move (e.g., “Sensex up 800 pts on Fed rate cut hopes”), **and**
- The move is *exceptionally large or unusual* (≥ 1.5% in Sensex/Nifty or major sector index).

Otherwise → **discard** as routine update.

---

### 🧾 OUTPUT FORMAT (STRICT JSON)
{
  "decision": "keep" or "discard",
  "reason": "brief reason (10–20 words)"
}



Do not add any extra commentary.
"""

# ================================
# 🧠 AGENT 2: SUMMARIZATION & SECTOR TAGGING (Updated)
# ================================
agent2_prompt = """
You are Agent 2, the Summarization & Sector Classification Agent for Rupee Letter — India’s finance and stock market platform.

### YOUR INPUT
You will receive:
1. A news article (title + content)
2. A company database (list of dicts) where each entry has: {"SYMBOL": "...", "NAME OF COMPANY": "..."}

### YOUR TASK
1. Summarize the article concisely in 40–60 words — factual, objective, investor-oriented.
2. From the given company database, find companies actually mentioned in the article.
   - Match by **exact name** or **symbol** (case-insensitive).
   - Include a company only if its name/symbol appears **anywhere in the article text**.
   - Do **not** infer or guess.
3. If one or more companies are found, set `"sector"` as `"Company Specific"`.
   If none found, set `"sector"` = `"General Market"`.
4. Set `"tone"` = `"neutral"` always.

### OUTPUT FORMAT (strict JSON only)
{
  "summary": "<40–60 word factual summary>",
  "sector": "<'Company Specific' or 'General Market'>",
  "companies": [<list of matched company names>],
  "tone": "neutral"
}
Return JSON only, no commentary.
"""
# ================================
# 🧠 AGENT 3: SENTIMENT & IMPACT ANALYZER
# ================================
agent3_prompt = """
You are Agent 3, the Sentiment & Impact Analyzer for Rupee Letter — India’s fast, actionable finance insights platform.

### YOUR ROLE
Analyze the summarized article and estimate:
1. **Short-term sentiment** (≈ 1 week outlook) for the mentioned company or market.
2. **Impact strength** of this news on price or sentiment.

### 📊 SENTIMENT SCALE
- "Very Bullish" → strong positive trigger; likely short-term upside.
- "Bullish" → moderately positive; supports price sentiment.
- "Neutral" → balanced or minimal directional bias.
- "Bearish" → moderately negative; may cause minor downside.
- "Very Bearish" → strong negative trigger; likely short-term drop.

### ⚡ IMPACT SCALE
- "Very High" → highly influential, major event (e.g., earnings surprise, policy shift, large order, merger).
- "High" → notable but not game-changing (e.g., mid-sized deal, positive rating).
- "Mild" → limited reaction expected.
- "Negligible" → almost no effect.

### 🧭 RULES
- Use financial reasoning — consider profits, losses, guidance, rating changes, major orders, or regulatory actions.
- If multiple companies, infer overall sentiment.
- If macro/policy news, assess general market tone.

### 🧾 OUTPUT FORMAT (STRICT JSON)
{
  "sentiment": "<Very Bullish | Bullish | Neutral | Bearish | Very Bearish>",
  "impact": "<Very High | High | Mild | Negligible>",
  "rationale": "<one short 15–25 word reasoning (for internal audit)>"
}
Return JSON only, no commentary.
"""

# ================================
# ⚙️ GROQ CALL HELPER
# ================================
def get_groq_response(system_prompt, user_input):
    try:
        response = groq_client.chat.completions.create(
            model="llama-3.1-8b-instant",
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_input},
            ],
            temperature=0.0,
        )
        return response.choices[0].message.content.strip()
    except Exception as e:
        print("❌ Groq API Error:", str(e))
        return None

# ================================
# 🧩 AGENT 1
# ================================
def process_agent1(article):
    title = article.get("Headline", "") or article.get("title", "")
    content = article.get("story", "") or article.get("content", "")
    text = f"Title: {title}\n\nContent:\n{content}"

    result = get_groq_response(agent1_prompt, text)
    if not result:
        return None
    try:
        decision_data = json.loads(result)
    except json.JSONDecodeError:
        print(f"⚠️ JSON parse error (Agent1): {title}")
        return None

    decision = decision_data.get("decision", "").lower()
    all_news.update_one(
        {"_id": article["_id"]},
        {"$set": {
            "processed_by_agent1": True,
            "decision": decision,
            "reason": decision_data.get("reason")
        }},
    )

    if decision == "keep":
        filtered_news.insert_one({
            **article,
            "decision": "keep",
            "reason": decision_data.get("reason"),
            "processed_at": datetime.utcnow()
        })
        print(f"✅ Kept: {title}")
    else:
        print(f"🗑️ Discarded: {title}")
    return decision_data

# ================================
# 🧩 AGENT 2 (Updated)
# ================================
def process_agent2(article):
    title = article.get("Headline", "") or article.get("title", "")
    content = article.get("story", "") or article.get("content", "")
    text = f"Title: {title}\n\nContent:\n{content}"

    # ✅ Fetch company data from your actual field names
    companies_data = list(companies_col.find({}, {"SYMBOL": 1, "NAME OF COMPANY": 1, "_id": 0}))
    company_list_json = json.dumps(companies_data, ensure_ascii=False)

    llm_input = f"""
Article:
{text}

Below is Rupee Letter's official company database (use only this list):
{company_list_json}

Now find which companies are mentioned in the article and summarize as instructed.
"""

    result = get_groq_response(agent2_prompt, llm_input)
    if not result:
        return None

    try:
        summary_data = json.loads(result)
    except json.JSONDecodeError:
        print(f"⚠️ JSON parse error (Agent2): {title}")
        print("Raw:", result)
        return None

    filtered_news.update_one(
        {"_id": article["_id"]},
        {"$set": {
            "summary": summary_data.get("summary"),
            "sector": summary_data.get("sector"),
            "companies": summary_data.get("companies", []),
            "tone": summary_data.get("tone", "neutral"),
            "processed_by_agent2": True
        }},
    )

    print(f"🧠 Summarized: {title} → {summary_data.get('sector')}")
    print(f"🏢 Companies found: {summary_data.get('companies', [])}")
    return summary_data
# ================================
# 🧩 AGENT 3
# ================================
def process_agent3(article):
    title = article.get("Headline", "") or article.get("title", "")
    summary = article.get("summary", "")
    sector = article.get("sector", "")
    companies = article.get("companies", [])

    if not summary:
        print(f"⚠️ Skipping Agent3: No summary for {title}")
        return None

    input_text = f"Summary: {summary}\nSector: {sector}\nCompanies: {', '.join(companies)}"
    result = get_groq_response(agent3_prompt, input_text)
    if not result:
        return None
    try:
        sentiment_data = json.loads(result)
    except json.JSONDecodeError:
        print(f"⚠️ JSON parse error (Agent3): {title}")
        print("Raw:", result)
        return None

    filtered_news.update_one(
        {"_id": article["_id"]},
        {"$set": {
            "sentiment": sentiment_data.get("sentiment"),
            "impact": sentiment_data.get("impact"),
            "rationale": sentiment_data.get("rationale"),
            "processed_by_agent3": True
        }},
    )
    print(f"📈 Sentiment: {sentiment_data.get('sentiment')} | Impact: {sentiment_data.get('impact')} for {title}")
    return sentiment_data

# ================================
# 🚀 PIPELINE RUNNER
# ================================
def run_pipeline(limit=20):
    unprocessed = all_news.find({"processed_by_agent1": {"$exists": False}}).limit(limit)
    for article in unprocessed:
        print(f"\n📰 Processing: {article.get('Headline', article.get('title', 'Untitled'))[:80]}...")
        decision = process_agent1(article)
        if decision and decision.get("decision") == "keep":
            summary_data = process_agent2(article)
            if summary_data:
                process_agent3({**article, **summary_data})
    print("\n🎯 Pipeline complete.")

# ================================
# 🏁 ENTRY POINT
# ================================
if __name__ == "__main__":
    run_pipeline()
