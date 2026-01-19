const express = require("express");
const router = express.Router();
const FilteredNews = require("../models/filteredNews");

/**
 * 🔥 TRENDING NEWS
 * GET /api/trending-news
 */
router.get("/", async (req, res) => {
 try {
    const trendingNews = await FilteredNews.find({
      $or: [
        { impact: "Very High" },
        { sentiment: { $in: ["Very Bullish", "Very Bearish"] } }
      ]
    })
      .sort({ published_at: -1 })
      .limit(50);

    res.status(200).json({
      success: true,
      count: trendingNews.length,
      data: trendingNews
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "Failed to fetch trending news",
      error: error.message
    });
  }
});

module.exports = router;


