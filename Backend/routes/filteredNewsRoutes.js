const express = require("express");
const router = express.Router();
const FilteredNews = require("../models/filteredNews");

// Helper function to extract main company name (remove "Limited", "Ltd", etc.)
function extractMainCompanyName(fullName) {
  if (!fullName) return "";
  const name = fullName.toString().trim();
  // Remove common suffixes (case-insensitive)
  return name
    .replace(/\s+(Limited|Ltd|Ltd\.|Incorporated|Inc\.|Inc|Corporation|Corp\.|Corp|Private|Pvt\.|Pvt)\s*$/i, "")
    .trim();
}

// ✔ Fetch all filtered news sorted by PublishedAt
router.get("/", async (req, res) => {
  try {
    console.log("📰 [FILTERED-NEWS] Fetching all filtered news...");
    const items = await FilteredNews.find().sort({ ingested_at: -1 }).limit(100);
    console.log(`✅ [FILTERED-NEWS] Found ${items.length} filtered news items`);
    res.json(items);
  } catch (err) {
    console.error("🔥 [FILTERED-NEWS] Error fetching filtered news:", err);
    console.error("🔥 [FILTERED-NEWS] Error details:", err.message);
    res.status(500).json({ error: "Server error while fetching filtered news" });
  }
});

// ✔ Fetch filtered news by company name (case-insensitive)
router.get("/company/:companyName", async (req, res) => {
  try {
    const companyName = decodeURIComponent(req.params.companyName);
    console.log(`📰 [FILTERED-NEWS] Fetching filtered news for company: "${companyName}"`);
    
    // Find news where sector is "Company Specific" 
    const allItems = await FilteredNews.find({
      sector: "Company Specific"
    }).sort({ ingested_at: -1 });
    
    console.log(`📊 [FILTERED-NEWS] Total Company Specific news items: ${allItems.length}`);
    
    // Extract main company name from search term (remove "Limited", "Ltd", etc.)
    const mainSearchName = extractMainCompanyName(companyName);
    const normalizedSearchName = mainSearchName.toLowerCase();
    const fullNormalizedSearchName = companyName.trim().toLowerCase();
    
    console.log(`🔍 [FILTERED-NEWS] Searching with main name: "${mainSearchName}" (normalized: "${normalizedSearchName}")`);
    
    // Filter to match company name case-insensitively in companies array
    const items = allItems.filter(item => {
      const companies = item.companies || [];
      return companies.some(comp => {
        if (!comp) return false;
        const compStr = comp.toString().trim();
        const normalizedComp = compStr.toLowerCase();
        const mainCompName = extractMainCompanyName(compStr).toLowerCase();
        
        // Try multiple matching strategies:
        // 1. Exact match (full name)
        if (normalizedComp === fullNormalizedSearchName) return true;
        
        // 2. Main name match (without Limited/Ltd)
        if (mainCompName === normalizedSearchName) return true;
        
        // 3. Contains match (either direction)
        if (normalizedComp.includes(normalizedSearchName) || 
            normalizedSearchName.includes(normalizedComp)) return true;
        
        // 4. Main name contains match
        if (mainCompName.includes(normalizedSearchName) || 
            normalizedSearchName.includes(mainCompName)) return true;
        
        return false;
      });
    });
    
    console.log(`✅ [FILTERED-NEWS] Found ${items.length} news items for "${companyName}"`);
    if (items.length === 0 && allItems.length > 0) {
      console.log(`⚠️ [FILTERED-NEWS] Sample companies in first item:`, allItems[0].companies);
      // Show first few company names for debugging
      const sampleCompanies = allItems.slice(0, 5).map(item => item.companies).flat();
      console.log(`📋 [FILTERED-NEWS] Sample company names in DB:`, [...new Set(sampleCompanies)]);
    }
    res.json(items);
  } catch (err) {
    console.error("🔥 [FILTERED-NEWS] Error fetching company filtered news:", err);
    res.status(500).json({ error: "Server error while fetching company filtered news" });
  }
});

// ✔ Optional: Fetch single filtered news article (if needed)
router.get("/:id", async (req, res) => {
  try {
    const item = await FilteredNews.findById(req.params.id);
    if (!item) return res.status(404).json({ error: "Filtered news not found" });
    res.json(item);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Error fetching filtered news item" });
  }
});

module.exports = router;

