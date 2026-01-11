const express = require("express");
const mongoose = require("mongoose");
const router = express.Router();
const User = require("../models/user");

// =======================
// SAVE / UNSAVE NEWS
// =======================
router.post("/save-news", async (req, res) => {
  try {
    const { userId, newsId } = req.body;

    if (!userId || !newsId) {
      return res.status(400).json({ message: "userId and newsId required" });
    }

    // ✅ Validate ObjectIds
    if (!mongoose.Types.ObjectId.isValid(userId) ||
        !mongoose.Types.ObjectId.isValid(newsId)) {
      return res.status(400).json({ message: "Invalid ObjectId" });
    }

    const user = await User.findById(userId);
    if (!user) return res.status(404).json({ message: "User not found" });

    // ✅ Ensure array exists (for old users)
    if (!Array.isArray(user.saved_news)) {
      user.saved_news = [];
    }

    const index = user.saved_news.findIndex(
      (n) => n.newsId.toString() === newsId
    );

    if (index > -1) {
      // ❌ UNSAVE
      user.saved_news.splice(index, 1);
    } else {
      // ✅ SAVE
      user.saved_news.push({
        newsId: new mongoose.Types.ObjectId(newsId),
        savedAt: new Date()
      });
    }

    await user.save();

    res.status(200).json({
      success: true,
      saved: index === -1
    });
  } catch (err) {
    console.error("Save news error:", err);
    res.status(500).json({ message: "Internal server error" });
  }
});

// =======================
// FETCH SAVED NEWS
// =======================
router.get("/:userId/saved-news", async (req, res) => {
  try {
    const { userId } = req.params;

    if (!mongoose.Types.ObjectId.isValid(userId)) {
      return res.status(400).json({ message: "Invalid userId" });
    }

    const user = await User.findById(userId)
      .populate("saved_news.newsId");

    if (!user) return res.status(404).json({ message: "User not found" });

    res.json({
      success: true,
      count: user.saved_news.length,
      data: user.saved_news.map((n) => n.newsId)
    });
  } catch (err) {
    console.error("Fetch saved news error:", err);
    res.status(500).json({ message: "Internal server error" });
  }
});

// DELETE ALL SAVED NEWS
router.delete("/:userId/saved-news", async (req, res) => {
  const user = await User.findById(req.params.userId);
  if (!user) return res.status(404).json({ message: "User not found" });

  user.saved_news = [];
  await user.save();

  res.json({ success: true });
});


module.exports = router;
