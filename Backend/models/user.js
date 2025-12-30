const mongoose = require("mongoose");

const userSchema = new mongoose.Schema(
  {
    name: { type: String, required: true },
    email: { type: String, required: true, unique: true },
    password: { type: String }, // Not required for social login
    googleId: { type: String, sparse: true, unique: true }, // Google OAuth ID
    uid: { type: String }, // Firebase UID
    loginType: { type: String, enum: ["email", "google", "apple", "facebook"], default: "email" },
    createdAt: { type: Date, default: Date.now },
    lastLogin: { type: Date, default: Date.now },
  },
  { collection: "Users" } // 👈 use your exact collection name
);

// Index for email uniqueness
userSchema.index({ email: 1 }, { unique: true });

// Index for googleId (allows null values)
userSchema.index({ googleId: 1 }, { unique: true, sparse: true });

module.exports = mongoose.model("User", userSchema);
