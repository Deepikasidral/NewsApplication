const mongoose = require("mongoose");

const savedNewsSchema = new mongoose.Schema(
  {
    newsId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "FilteredNews",
      required: true,
    },
    savedAt: {
      type: Date,
      default: Date.now,
    },
  },
  { _id: false }
);
const savedEventSchema = new mongoose.Schema(
  {
    eventId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Event", // 👈 your events model name
      required: true,
    },
    savedAt: {
      type: Date,
      default: Date.now,
    },
  },
  { _id: false }
);


const userSchema = new mongoose.Schema(
  {
    name: { type: String, required: true },
    email: { type: String, required: true, unique: true },
    password: { type: String }, // email login
    googleId: { type: String, sparse: true, unique: true },
    uid: { type: String }, // Firebase UID (optional)
    loginType: {
      type: String,
      enum: ["email", "google", "apple", "facebook"],
      default: "email",
    },

    // ✅ ADD THIS
    saved_news: {
      type: [savedNewsSchema],
      default: [],
    },
    saved_events: {
      type: [savedEventSchema],
      default: [],
    },
    notifications: {
        type: Boolean,
        default: true
      },
      fcmToken: {
  type: String,
  default: ""
},
totalTimeSpent: {
  type: Number,
  default: 0
},
sessions: [
  {
    duration: Number,
    timestamp: Date,
  },
],
newsViews: {
  type: Map,
  of: Number,
  default: {}
},


    createdAt: { type: Date, default: Date.now },
    lastLogin: { type: Date, default: Date.now },
  },
  { collection: "Users" }
);

// Indexes
userSchema.index({ email: 1 }, { unique: true });
userSchema.index({ googleId: 1 }, { unique: true, sparse: true });

module.exports = mongoose.model("User", userSchema);
