const express = require("express");
const mongoose = require("mongoose");
const User = require("../models/user");

const router = express.Router();

// SAVE / UNSAVE EVENT
router.post("/save-event", async (req, res) => {
  try {
    const { userId, eventId } = req.body;

    if (!mongoose.Types.ObjectId.isValid(userId) ||
        !mongoose.Types.ObjectId.isValid(eventId)) {
      return res.status(400).json({ message: "Invalid ObjectId" });
    }

    const user = await User.findById(userId);
    if (!user) return res.status(404).json({ message: "User not found" });

    const index = user.saved_events.findIndex(
      (e) => e.eventId.toString() === eventId
    );

    if (index > -1) {
      user.saved_events.splice(index, 1); // UNSAVE
    } else {
      user.saved_events.push({ eventId });
    }

    await user.save();

    res.json({ success: true, saved: index === -1 });
  } catch (err) {
    res.status(500).json({ message: "Server error" });
  }
});

// FETCH SAVED EVENTS
router.get("/:userId/saved-events", async (req, res) => {
  const { userId } = req.params;

  const user = await User.findById(userId)
    .populate("saved_events.eventId");

  if (!user) return res.status(404).json({ message: "User not found" });

  res.json({
    success: true,
    data: user.saved_events.map((e) => e.eventId),
  });
});

module.exports = router;
