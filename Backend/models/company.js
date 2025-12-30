const mongoose = require("mongoose");

const companySchema = new mongoose.Schema({
  Symbol: String,
  "Company Name": String,
  Industry: String,
});

module.exports = mongoose.model("new_company_data", companySchema, "new_company_data");

