const mongoose = require("mongoose");

const userSchema = new mongoose.Schema(
  {
    name: { type: String, required: true },
    email: { type: String, required: true, unique: true },
    password: { type: String }, // Not required for social login
    loginType: { type: String, enum: ["email", "google"], default: "email" },
    createdAt: { type: Date, default: Date.now },
  },
  { collection: "Users" } // 👈 use your exact collection name
);

module.exports = mongoose.model("User", userSchema);
