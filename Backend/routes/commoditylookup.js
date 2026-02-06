const express = require("express");
const router = express.Router();
const Commodity = require("../models/commodities");

router.get("/by-name", async (req, res) => {
  try {
    const { name } = req.query;

    if (!name) {
      return res.status(400).json({ error: "Commodity name required" });
    }

    const commodity = await Commodity.findOne(
      { "NAME OF SECTOR": new RegExp(`^${name}$`, "i") }, // case-insensitive
      {
        SYMBOL: 1,
        "NAME OF SECTOR": 1,
        _id: 0
      }
    ).lean();

    if (!commodity) return res.json({ success: false });

    res.json({
      success: true,
      data: {
        name: commodity["NAME OF SECTOR"],
        symbol: commodity["SYMBOL"]   // ⭐ return full symbol like TVC:GOLD
      }
    });

  } catch (e) {
    console.error("Commodity lookup error:", e);
    res.status(500).json({ error: "Commodity lookup error" });
  }
});

module.exports = router;
