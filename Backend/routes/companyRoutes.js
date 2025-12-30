const express = require("express");
const router = express.Router();
const Company = require("../models/company");

// ✔ Fetch all companies sorted by NAME OF COMPANY
router.get("/", async (req, res) => {
  try {
    console.log("📊 Fetching companies from new_company_data collection...");
    const items = await Company.find().sort({ "Company Name": 1 });
    console.log(`✅ Found ${items.length} companies`);
    res.json(items);
  } catch (err) {
    console.error("🔥 Error fetching companies:", err);
    console.error("🔥 Error details:", err.message);
    console.error("🔥 Error stack:", err.stack);
    res.status(500).json({ error: "Server error while fetching companies", details: err.message });
  }
});

// ✔ Optional: Fetch single company (if needed)
router.get("/:id", async (req, res) => {
  try {
    const item = await Company.findById(req.params.id);
    if (!item) return res.status(404).json({ error: "Company not found" });
    res.json(item);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Error fetching company item" });
  }
});

module.exports = router;

