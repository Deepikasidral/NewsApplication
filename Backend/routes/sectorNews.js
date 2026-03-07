const express = require("express");
const router = express.Router();
const FilteredNews = require("../models/filteredNews");

router.get("/", async (req, res) => {
  try {
    const sectorNews = await FilteredNews.find({
      sector_market: { $exists: true, $ne: "" }
    })
      .sort({ ingested_at: -1 })
      .limit(50);

    res.status(200).json({
      success: true,
      count: sectorNews.length,
      data: sectorNews
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "Failed to fetch sector news",
      error: error.message
    });
  }
});

module.exports = router;
