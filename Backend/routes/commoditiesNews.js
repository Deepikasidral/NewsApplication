const express = require("express");
const router = express.Router();
const FilteredNews = require("../models/filteredNews");

/**
 * 🛢 COMMODITIES NEWS
 * GET /api/commodities-news
 * Condition:
 * commodities === true
 */
router.get("/", async (req, res) => {
  try {
    const commoditiesNews = await FilteredNews.find({
      commodities: true
    })
      .sort({ ingested_at: -1 })
      .limit(50);

    res.status(200).json({
      success: true,
      count: commoditiesNews.length,
      data: commoditiesNews
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "Failed to fetch commodities news",
      error: error.message
    });
  }
});

module.exports = router;
