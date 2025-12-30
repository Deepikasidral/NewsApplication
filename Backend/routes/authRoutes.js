const express = require("express");
const bcrypt = require("bcryptjs");
const User = require("../models/user");
const router = express.Router();

// SIGN UP (Email)
router.post("/signup", async (req, res) => {
  try {
    const { name, email, password, loginType } = req.body;

    if (!name || !email || (loginType === "email" && !password))
      return res.status(400).json({ message: "All fields are required" });

    const existingUser = await User.findOne({ email });
    if (existingUser)
      return res.status(400).json({ message: "Email already registered" });

    let hashedPassword;
    if (loginType === "email") {
      hashedPassword = await bcrypt.hash(password, 10);
    }

    const user = new User({
      name,
      email,
      password: hashedPassword,
      loginType: loginType || "email",
    });

    await user.save();

    res.status(201).json({
      message: "User registered successfully",
      user: { id: user._id, name: user.name, email: user.email, loginType: user.loginType },
    });
  } catch (error) {
    console.error("❌ SIGNUP ERROR:", error.message);     // print only message
    console.error("📄 FULL ERROR:", error);               // full stack trace
    res.status(500).json({ message: "Server error", error: error.message });
  }
});

// SIGN IN (Email)
router.post("/signin", async (req, res) => {
  try {
    const { email, password, loginType } = req.body;

    const user = await User.findOne({ email });
    if (!user)
      return res.status(400).json({ message: "User not found" });

    if (user.loginType !== (loginType || "email")) {
      return res.status(400).json({ message: `Please login with ${user.loginType}` });
    }

    if (user.loginType === "email") {
      const isMatch = await bcrypt.compare(password, user.password);
      if (!isMatch)
        return res.status(400).json({ message: "Invalid password" });
    }

    res.json({
      message: "Sign in successful",
      user: { id: user._id, name: user.name, email: user.email, loginType: user.loginType },
    });
  } catch (error) {
    console.error("❌ SIGNIN ERROR:", error.message);
    console.error("📄 FULL ERROR:", error);
    res.status(500).json({ message: "Server error", error: error.message });
  }
});

// GOOGLE LOGIN
router.post("/google-login", async (req, res) => {
  try {
    const { name, email, uid, googleId } = req.body;

    if (!email) {
      return res.status(400).json({ message: "Email is required" });
    }

    // Find user by email or googleId
    let user = await User.findOne({
      $or: [{ email }, { googleId: googleId || null }]
    });

    if (!user) {
      // Create new user
      user = new User({
        name,
        email,
        loginType: "google",
        uid,
        googleId,
        lastLogin: new Date(),
      });
      await user.save();
      
      return res.status(201).json({
        message: "Google account created successfully",
        user: {
          id: user._id,
          name: user.name,
          email: user.email,
          loginType: user.loginType,
        },
      });
    }

    // Update existing user
    user.name = name;
    user.loginType = "google";
    user.lastLogin = new Date();
    
    if (uid && !user.uid) {
      user.uid = uid;
    }
    if (googleId && !user.googleId) {
      user.googleId = googleId;
    }
    
    await user.save();

    res.json({
      message: "Google login successful",
      user: {
        id: user._id,
        name: user.name,
        email: user.email,
        loginType: user.loginType,
      },
    });
  } catch (error) {
    console.error("❌ GOOGLE LOGIN ERROR:", error.message);
    console.error("📄 FULL ERROR:", error);
    
    if (error.code === 11000) {
      return res.status(400).json({
        message: "This Google account is already registered",
      });
    }
    
    res.status(500).json({
      message: "Server error during Google login",
      error: error.message,
    });
  }
});

module.exports = router;