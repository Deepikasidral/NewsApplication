const express = require("express");
const router = express.Router();
const FilteredNews = require("../models/filteredNews");

const YahooFinance = require("yahoo-finance2").default;
const yahooFinance = new YahooFinance();

const NodeCache = require("node-cache");
const cache = new NodeCache({ stdTTL: 60 });

const { exec } = require("child_process");
const path = require("path");

/*
GLOBAL INDICES
*/
const globalSymbols = [
  "^GSPC",   // VANTAGE:SP500
  "^DJI",    // TVC:DJI
  "^IXIC",   // NASDAQ:IXIC
  "^HSI",    // TVC:HSI
  "^N225",   // TVC:NI225
];

/*
POST /api/index/data
*/
router.post("/data", async (req, res) => {

  console.log("🔥 /data API HIT");
  console.log("BODY:", req.body);

  try {

    const { symbol } = req.body;

    if (!symbol) {
      return res.status(400).json({ error: "Symbol required" });
    }

    const cacheKey = `data_${symbol}`;

    if (cache.has(cacheKey)) {
      console.log("⚡ Serving /data from cache");
      return res.json(cache.get(cacheKey));
    }

    /*
    1️⃣ INDEX PRICE
    */
    const quote = await yahooFinance.quote(symbol);

    /*
    2️⃣ CHART DATA
    */
    const endDate = new Date();
const startDate = new Date();
startDate.setDate(endDate.getDate() - 7);

const chart = await yahooFinance.chart(symbol, {
  period1: startDate,
  period2: endDate,
  interval: "1d",
});

    /*
    3️⃣ TOP MOVERS (PYTHON SCRIPT)
    */
    const movers = await new Promise((resolve, reject) => {

      console.log("➡️ Running python script...");

      const pythonPath = path.join(__dirname, "..", "venv", "bin", "python");
      
      const scriptPath = path.join(__dirname, "..", "nse_movers.py");

      exec(
        `"${pythonPath}" "${scriptPath}" "${symbol}"`,
        (error, stdout, stderr) => {

          if (error) {
            console.log("❌ PYTHON ERROR:", error);
            console.log("❌ STDERR:", stderr);
            reject(error);
            return;
          }

          try {
            const parsed = JSON.parse(stdout);
            resolve(parsed);
          } catch (e) {
            console.log("❌ JSON PARSE ERROR:", e);
            reject(e);
          }
        }
      );
    });

    /*
    4️⃣ FETCH NEWS FROM DB
    */
    let news = [];

    // NIFTY
    if (symbol === "^NSEI") {

      news = await FilteredNews.find({
        global: false,
        commodities: false
      })
      .sort({ ingested_at: -1 })
      .limit(10);

    }

    // BANK NIFTY
    else if (symbol === "^NSEBANK") {

      news = await FilteredNews.find({
        sector_market: "Nifty Bank"
      })
      .sort({ ingested_at: -1 })
      .limit(10);

    }

    // IT SECTOR
    else if (symbol === "^CNXIT") {

      news = await FilteredNews.find({
        sector_market: "Nifty IT"
      })
      .sort({ ingested_at: -1 })
      .limit(10);

    }

    
    /*
    FINAL RESPONSE
    */
    const responseData = {

      indexName: quote.shortName,
      price: quote.regularMarketPrice,
      change: quote.regularMarketChange,
      changePercent: quote.regularMarketChangePercent,

      chart: chart.quotes || [],

      gainers: movers.gainers || [],
      losers: movers.losers || [],

      news: news
    };

    cache.set(cacheKey, responseData);

    res.json(responseData);

  } catch (error) {

    console.log(error);

    res.status(500).json({
      error: "Failed to fetch index data"
    });

  }
});


/*
GLOBAL INDEX DATA
*/
router.post("/global", async (req, res) => {

  try {

    const cacheKey = "global_data";

    if (cache.has(cacheKey)) {
      console.log("⚡ Serving /global from cache");
      return res.json(cache.get(cacheKey));
    }

    const data = await Promise.all(

      globalSymbols.map(async (symbol) => {

        const quote = await yahooFinance.quote(symbol);

        const endDate = new Date();
const startDate = new Date();
startDate.setDate(endDate.getDate() - 7);

const chart = await yahooFinance.chart(symbol, {
  period1: startDate,
  period2: endDate,
  interval: "1d",
});

        const nameMap = {
  "^GSPC": "S&P 500",
  "^DJI": "Dow Jones",
  "^IXIC": "NASDAQ",
  "^HSI": "Hang Seng",
  "^N225": "Nikkei 225",
};

return {
  symbol,
  name: nameMap[symbol],
  price: quote.regularMarketPrice,
  chart: chart.quotes || [],
};

      })

    );

    cache.set(cacheKey, data);

    res.json(data);

  } catch (e) {

    console.log(e);

    res.status(500).json({
      error: "Failed global data"
    });

  }

});


module.exports = router;