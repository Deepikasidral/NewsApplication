const mongoose = require("mongoose");

const newsSchema = new mongoose.Schema(
  {
    // ==============================
    // 🔹 PTI ORIGINAL FIELDS
    // ==============================
    FileName: { type: String, unique: true },
    Bylines: String,
    Copyrights: String,
    EDNote: String,
    Headline: String,
    Priority: String,
    PublishedAt: String,
    category: String,
    link: String,
    slug: String,
    source: String,
    story: String,
    subcategory: String,

    // 🔥 Deduplication (IMPORTANT - matches Python)
    content_hash: {
      type: String,
      unique: true,
      index: true
    },

    // ==============================
    // 🔹 AGENT 1
    // ==============================
    decision: String,
    filter_reason: String,

    // ==============================
    // 🔹 AGENT 2 (Rupee Letter Layer)
    // ==============================
    summary: String,
    sector: String, // IPO / Banking / Macro etc
    companies: [String],
    global: Boolean,
    commodities: Boolean,

    // 🔥 Trading/Market Overrides (NEW)
    sector_market: String,             // Nifty Bank / Nifty IT etc
    commodities_market: [String],      // GOLD / CRUDE OIL etc

    // ==============================
    // 🔹 AGENT 3
    // ==============================
    sentiment: String,
    impact: String,
    impact_rationale: String,

    // ==============================
    // 🔹 SYSTEM
    // ==============================
    ingested_at: {
      type: Date,
      index: true,
      required: true
    }
  },
  { timestamps: false }
);

// Explicit collection name
module.exports = mongoose.model(
  "filtered_news",
  newsSchema,
  "filtered_news"
);
