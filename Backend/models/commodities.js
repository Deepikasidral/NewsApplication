const mongoose = require("mongoose");

const commoditySchema = new mongoose.Schema(
  {
   SYMBOL: {
      type: String,
      required: true,
      trim: true,
    },
    "NAME OF SECTOR": {
      type: String,
      required: true,
      trim: true,
    }
  },
  { collection: "Commodities" }
);

module.exports = mongoose.model("Commodity", commoditySchema);
