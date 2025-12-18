const mongoose = require("mongoose");

const companySchema = new mongoose.Schema({
  SYMBOL: String,
  "NAME OF COMPANY": String,
});

// Your collection is `Company_data`, so:
module.exports = mongoose.model("Company_data", companySchema, "Company_data");

