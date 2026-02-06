const express = require("express");
const router = express.Router();
const Sector = require("../models/sector");

router.get("/by-name", async (req, res) => {
  try {
    const { name } = req.query;

    if (!name) {
      return res.status(400).json({ error: "Sector name required" });
    }

    const sector = await Sector.findOne(
      { "NAME OF SECTOR": name },
      {
        SYMBOL: 1,
        "NAME OF SECTOR": 1,
        _id: 0
      }
    ).lean();

    if (!sector) return res.json({ success: false });

    res.json({
      success: true,
      data: {
        name: sector["NAME OF SECTOR"],
        symbol: sector["SYMBOL"],
        exchange: "NSE"   // default fallback
      }
    });

  } catch (e) {
    console.error("Sector lookup error:", e);
    res.status(500).json({ error: "Sector lookup error" });
  }
});

module.exports = router;
