const mongoose = require("mongoose");

const filteredNewsSchema = new mongoose.Schema({
  FileName: String,
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
  decision: String,
  reason: String,
  sector: String,
  companies: [String],
  summary: String,
  tone: String,
  impact: String,
  sentiment: String,
  rationale: String,
  processed_by_agent2: Boolean,
  processed_by_agent3: Boolean,
  processed_at: Date
}, { collection: "filtered_news" });

// Your collection is `filtered_news`, so:
module.exports = mongoose.model("FilteredNews", filteredNewsSchema, "filtered_news");

