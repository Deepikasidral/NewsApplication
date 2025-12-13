const express = require("express");
const router = express.Router();
const News = require("../models/news");

// ✔ Fetch all news sorted by PublishedAt
router.get("/", async (req, res) => {
  try {
    const items = await News.find().sort({ PublishedAt: -1 });
    res.json(items);
  } catch (err) {
    console.error("🔥 Error fetching news:", err);
    res.status(500).json({ error: "Server error while fetching news" });
  }
});

// ✔ Optional: Fetch single article (if needed)
router.get("/:id", async (req, res) => {
  try {
    const item = await News.findById(req.params.id);
    if (!item) return res.status(404).json({ error: "News not found" });
    res.json(item);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Error fetching news item" });
  }
});

module.exports = router;