const express = require("express");
const mongoose = require("mongoose");
const dotenv = require("dotenv");
const cors = require("cors");

// Routes
const authRoutes = require("./routes/authRoutes");
const newsRoutes = require("./routes/newsRoutes");
const companyRoutes = require("./routes/companyRoutes");
const filteredNewsRoutes = require("./routes/filteredNewsRoutes");
const eventRoutes = require("./routes/eventRoutes");
const trendingNewsRoutes = require("./routes/trendingNews");
const globalNewsRoutes = require("./routes/globalNews");
const commoditiesNewsRoutes = require("./routes/commoditiesNews");


//const summarizerRoutes = require("./routes/summarizer");

dotenv.config();

const app = express();

// Middlewares
app.use(cors());
app.use(express.json());

// Routes
app.use("/api/auth", authRoutes);
app.use("/api/news", newsRoutes);
app.use("/api/companies", companyRoutes);
app.use("/api/filtered-news", filteredNewsRoutes);
app.use("/api/events", eventRoutes);
app.use("/api/trending-news", trendingNewsRoutes);
app.use("/api/global-news", globalNewsRoutes);
app.use("/api/commodities-news", commoditiesNewsRoutes);


// Test route to verify server is running
app.get("/api/test", (req, res) => {
  res.json({ message: "Server is running", routes: ["/api/news", "/api/filtered-news", "/api/companies", "/api/auth","/api/events"] });
});



// Health check route
app.get("/", (req, res) => res.send("📰 News API Backend is running"));

// MongoDB connection & server start
const PORT = process.env.PORT || 5000;
mongoose
  .connect(process.env.MONGO_URI, {
    useNewUrlParser: true,
    useUnifiedTopology: true,
  })
  .then(() => {
    console.log("✅ MongoDB connected");
    app.listen(PORT, () => console.log(`🚀 Server running on port ${PORT}`));
  })
  .catch((err) => console.error("MongoDB connection error:", err));
