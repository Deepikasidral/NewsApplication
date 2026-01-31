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
    EXCHANGE: {
      type: String,
      trim: true,
      default: "NSE",
    },
  },
  {
    collection: "Company_data",
    timestamps: false,
    strict: false, // still OK for spaced fields
  }
);

module.exports = mongoose.model("Company", companySchema);
