const mongoose = require("mongoose");

const newsSchema = new mongoose.Schema(
  {
    // PTI fields
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

    // Agent 1
    decision: String,
    filter_reason: String,

    // Agent 2
    summary: String,
    sector: String,
    companies: [String],
    global: Boolean,
    commodities: Boolean,

    // Agent 3
    sentiment: String,
    impact: String,
    impact_rationale: String,

    // System (🔥 MOST IMPORTANT)
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