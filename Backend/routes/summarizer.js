require("dotenv").config();
const express = require("express");
const OpenAI = require("openai");
const router = express.Router();

// Initialize OpenAI with API key from .env
const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

// POST /summarize
router.post("/", async (req, res) => {
  const { text } = req.body;
  if (!text) return res.status(400).json({ error: "No text provided" });

  try {
    const completion = await openai.chat.completions.create({
      model: "gpt-4o-mini",
      messages: [
        {
          role: "system",
          content: "You are a helpful financial news summarizer.",
        },
        {
          role: "user",
          content: `Summarize this article in 3 sentences:\n\n${text}`,
        },
      ],
    });

    const summary = completion.choices[0].message.content;
    res.json({ summary });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: err.message || "Failed to summarize" });
  }
});

module.exports = router;
