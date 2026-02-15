const express = require("express");
const router = express.Router();
const News = require("../models/news");

// ✔ Fetch all news sorted by PublishedAt
router.get("/", async (req, res) => {
  try {
    const items = await News.find().sort({ ingested_at: -1 });
;
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

router.get("/sector/:sector", async (req, res) => {
  try {
    const sector = req.params.sector;

    const news = await News.find({
      sector: { $regex: new RegExp(`^${sector}$`, "i") }
    }).sort({ publishedAt: -1 });

    res.status(200).json({
      success: true,
      count: news.length,
      news,
    });
  } catch (err) {
    res.status(500).json({
      success: false,
      message: err.message,
    });
  }
});

module.exports = router;