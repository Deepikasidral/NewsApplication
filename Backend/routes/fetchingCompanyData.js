const express = require("express");
const router = express.Router();
const Company = require("../models/old_company");

router.get("/by-names", async (req, res) => {
  try {
    const { names } = req.query;

    if (!names) {
      return res.status(400).json({ error: "Company names required" });
    }

    const nameArray = names
      .split(",")
      .map(n => n.trim())
      .filter(Boolean);

    const docs = await Company.find(
      {
        "NAME OF COMPANY": { $in: nameArray }
      },
      {
        SYMBOL: 1,
        "NAME OF COMPANY": 1,
        EXCHANGE: 1,
        _id: 0
      }
    ).lean();

    const result = docs.map(d => ({
      name: d["NAME OF COMPANY"],
      symbol: d["SYMBOL"],
      exchange: d["EXCHANGE"] || "NSE", // ✅ fallback
    }));

    return res.json({ success: true, data: result });
  } catch (err) {
    console.error("Company lookup error:", err);
    return res.status(500).json({ error: "Error fetching company item" });
  }
});

module.exports = router;
