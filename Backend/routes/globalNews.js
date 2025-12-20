const express = require("express");
const router = express.Router();
const FilteredNews = require("../models/filteredNews");

/**
 * 🌍 GLOBAL NEWS
 * GET /api/global-news
 * Condition:
 * global === true
 */
router.get("/", async (req, res) => {
  try {
    const globalNews = await FilteredNews.find({
      global: true
    })
      .sort({ published_at: -1 })
      .limit(50);

    res.status(200).json({
      success: true,
      count: globalNews.length,
      data: globalNews
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "Failed to fetch global news",
      error: error.message
    });
  }
});

module.exports = router;
