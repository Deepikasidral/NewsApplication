const mongoose = require("mongoose");

const companySchema = new mongoose.Schema(
  {
    SYMBOL: {
      type: String,
      required: true,
      trim: true,
    },
    "NAME OF COMPANY": {
      type: String,
      required: true,
      trim: true,
    },
  },
  {
    collection: "Company_data", // ✅ matches Mongo
    timestamps: false,
    strict: false,              // ✅ REQUIRED for spaced fields
  }
);

module.exports = mongoose.model("Company", companySchema);
