const mongoose = require("mongoose");

const newsSchema = new mongoose.Schema({
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
  reason: String
});

// Your collection is `filtered_news`, so:
module.exports = mongoose.model("filtered_news", newsSchema);
