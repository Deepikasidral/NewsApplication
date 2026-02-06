const mongoose = require("mongoose");

const sectorSchema = new mongoose.Schema(
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
  { collection: "sector", strict: false }
);

module.exports = mongoose.model("Sector", sectorSchema);
