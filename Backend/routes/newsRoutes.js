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

// ✔ Fetch news by company name (case-insensitive)
router.get("/company/:companyName", async (req, res) => {
  try {
    const companyName = decodeURIComponent(req.params.companyName);
    console.log(`📰 Fetching news for company: "${companyName}"`);
    
    // Find news where sector is "Company Specific" 
    // Then filter in JavaScript for case-insensitive matching in companies array
    const allItems = await News.find({
      sector: "Company Specific"
    }).sort({ PublishedAt: -1 });
    
    console.log(`📊 Total Company Specific news items: ${allItems.length}`);
    
    // Normalize company name for comparison (trim and lowercase)
    const normalizedSearchName = companyName.trim().toLowerCase();
    
    // Filter to match company name case-insensitively in companies array
    // Also handle whitespace and partial matches
    const items = allItems.filter(item => {
      const companies = item.companies || [];
      return companies.some(comp => {
        if (!comp) return false;
        const normalizedComp = comp.toString().trim().toLowerCase();
        // Exact match or contains match
        return normalizedComp === normalizedSearchName || 
               normalizedComp.includes(normalizedSearchName) ||
               normalizedSearchName.includes(normalizedComp);
      });
    });
    
    console.log(`✅ Found ${items.length} news items for "${companyName}"`);
    if (items.length === 0 && allItems.length > 0) {
      console.log(`⚠️ Sample companies in first item:`, allItems[0].companies);
    }
    res.json(items);
  } catch (err) {
    console.error("🔥 Error fetching company news:", err);
    res.status(500).json({ error: "Server error while fetching company news" });
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
