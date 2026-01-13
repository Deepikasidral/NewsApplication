const express = require("express");
const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");
const User = require("../models/user");
const { verifyToken } = require("../middleware/authMiddleware");
const router = express.Router();

const JWT_SECRET = process.env.JWT_SECRET || "your-secret-key-change-in-production";
const JWT_EXPIRY = "30d"; // 30 days like Instagram

// Generate JWT token
const generateToken = (userId) => {
  return jwt.sign({ userId }, JWT_SECRET, { expiresIn: JWT_EXPIRY });
};

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

    const token = generateToken(user._id);

   res.status(201).json({
  message: "User registered successfully",
  token,
  user: {
    _id: user._id,
    name: user.name,
    email: user.email,
    loginType: user.loginType,
  },
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
    user.lastLogin = new Date();
    await user.save();

    const token = generateToken(user._id);

  res.json({
  message: "Sign in successful",
  token,
  user: {
    _id: user._id,
    name: user.name,
    email: user.email,
    loginType: user.loginType,
  },
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
      
      const token = generateToken(user._id);
      
     return res.status(201).json({
  message: "Google account created successfully",
  token,
  user: {
    _id: user._id,
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

    const token = generateToken(user._id);

    res.json({
  message: "Google login successful",
  token,
  user: {
    _id: user._id,
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

// VERIFY TOKEN (check if session is still valid)
router.post("/verify-token", async (req, res) => {
  try {
    const { token } = req.body;

    if (!token) {
      return res.status(401).json({ message: "No token provided", valid: false });
    }

    const decoded = jwt.verify(token, JWT_SECRET);
    const user = await User.findById(decoded.userId).select("-password");

    if (!user) {
      return res.status(404).json({ message: "User not found", valid: false });
    }

    res.json({
      valid: true,
      user: {
        _id: user._id,
        name: user.name,
        email: user.email,
        loginType: user.loginType,
      },
    });
  } catch (error) {
    if (error.name === "TokenExpiredError") {
      return res.status(401).json({ message: "Token expired", valid: false });
    }
    res.status(401).json({ message: "Invalid token", valid: false });
  }
});

// REFRESH TOKEN (get new token before expiry)
router.post("/refresh-token", async (req, res) => {
  try {
    const { token } = req.body;

    if (!token) {
      return res.status(401).json({ message: "No token provided" });
    }

    const decoded = jwt.verify(token, JWT_SECRET);
    const user = await User.findById(decoded.userId);

    if (!user) {
      return res.status(404).json({ message: "User not found" });
    }

    const newToken = generateToken(user._id);

    res.json({
      message: "Token refreshed",
      token: newToken,
    });
  } catch (error) {
    res.status(401).json({ message: "Invalid or expired token" });
  }
});

// LOGOUT (optional - client-side token deletion is enough)
router.post("/logout", verifyToken, async (req, res) => {
  res.json({ message: "Logged out successfully" });
});

// GET CURRENT USER (protected route example)
router.get("/me", verifyToken, async (req, res) => {
  res.json({
    user: {
      _id: req.user._id,
      name: req.user.name,
      email: req.user.email,
      loginType: req.user.loginType,
    },
  });
});

module.exports = router;