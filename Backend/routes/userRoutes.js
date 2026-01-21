const express = require("express");
const User = require("../models/user");
const router = express.Router();

/// FETCH PROFILE
router.post("/", async (req, res) => {
  try {
    const { userId } = req.body;

    const user = await User.findById(userId).select(
  "name email notifications"
);


    if (!user) {
      return res.status(404).json({ message: "User not found" });
    }

    res.json({ success: true, user });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

router.post("/logout", async (req, res) => {
  const { userId } = req.body;
  await User.findByIdAndUpdate(userId, { lastLogin: new Date() });
  res.json({ success: true });
});

/// 🔔 UPDATE NOTIFICATION SETTING
router.post("/notifications", async (req, res) => {
  try {
    const { userId, enabled } = req.body;

    console.log("🔔 Notification toggle request:", {
      userId,
      enabled
    });

    const updatedUser = await User.findByIdAndUpdate(
      userId,
      { notifications: enabled },
      { new: true }
    );

    console.log("✅ Updated user:", updatedUser);

    res.json({ success: true });
  } catch (err) {
    console.error("❌ Notification update failed:", err);
    res.status(500).json({ success: false, error: err.message });
  }
});


/// 📊 GET ANALYTICS DASHBOARD (must be before POST /analytics)
router.get("/analytics/dashboard", async (req, res) => {
  try {
    const users = await User.find({}, "name email totalTimeSpent sessions");
    
    const analytics = users.map(u => ({
      name: u.name,
      email: u.email,
      totalMinutes: Math.round((u.totalTimeSpent || 0) / 60),
      sessionCount: u.sessions?.length || 0,
      avgSessionMinutes: u.sessions?.length 
        ? Math.round((u.totalTimeSpent || 0) / u.sessions.length / 60) 
        : 0,
    }));

    res.json({ success: true, analytics });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

/// 📊 ANALYTICS - TRACK SESSION
router.post("/analytics", async (req, res) => {
  try {
    const { userId, sessionDuration, timestamp } = req.body;

    await User.findByIdAndUpdate(userId, {
      $inc: { totalTimeSpent: sessionDuration },
      $push: {
        sessions: {
          duration: sessionDuration,
          timestamp: new Date(timestamp),
        },
      },
    });

    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});
router.post("/save-fcm", async (req, res) => {
  try {
    const { userId, fcmToken } = req.body;

    console.log("📩 save-fcm called:", { userId, fcmToken });

    if (!userId || !fcmToken) {
      return res.status(400).json({ success: false, reason: "Missing data" });
    }

    const updatedUser = await User.findByIdAndUpdate(
      userId,
      { $set: { fcmToken } },
      { new: true }
    );

    if (!updatedUser) {
      console.error("❌ User not found for FCM save");
      return res.status(404).json({ success: false });
    }

    console.log("✅ FCM token stored for user:", updatedUser.email);

    res.json({ success: true });
  } catch (err) {
    console.error("❌ save-fcm error:", err);
    res.status(500).json({ success: false });
  }
});


module.exports = router;
