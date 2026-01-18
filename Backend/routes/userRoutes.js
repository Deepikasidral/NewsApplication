const express = require("express");
const User = require("../models/user");
const router = express.Router();

/// FETCH PROFILE
router.post("/profile", async (req, res) => {
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

    await User.findByIdAndUpdate(userId, {
      notifications: enabled,
    });

    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});
router.post("/save-fcm", async (req, res) => {
  try {
    const { userId, fcmToken } = req.body;

    await User.findByIdAndUpdate(userId, { fcmToken });
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ success: false });
  }
});


module.exports = router;
