const express = require("express");
const router = express.Router();
const FilteredNews = require("../models/filteredNews");

const YahooFinance = require("yahoo-finance2").default;
const yahooFinance = new YahooFinance();

const NodeCache = require("node-cache");
const cache = new NodeCache({ stdTTL: 300 }); // 5 minutes cache

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

const sectorSymbols = [
  { symbol: "^NSEBANK", name: "Nifty Bank" },
  { symbol: "^CNXIT", name: "Nifty IT" },
  { symbol: "^CNXPHARMA", name: "Nifty Pharma" },
  { symbol: "^CNXFMCG", name: "Nifty FMCG" },
  { symbol: "^CNXAUTO", name: "Nifty Auto" },
  { symbol: "^CNXMETAL", name: "Nifty Metal" },
  { symbol: "^CNXENERGY", name: "Nifty Energy" },
  { symbol: "^CNXFINANCE", name: "Nifty Financial Services" },
  { symbol: "^CNXREALTY", name: "Nifty Realty" },
  { symbol: "^CNXOILGAS", name: "Nifty Oil & Gas" },
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

    const endDate = new Date();
    const startDate = new Date();
    startDate.setDate(endDate.getDate() - 30); // 30 days to always have data

    let newsQuery;
    if (symbol === "^NSEI") {
      newsQuery = { global: false, commodities: false };
    } else if (symbol === "^NSEBANK") {
      newsQuery = { sector_market: "Nifty Bank" };
    } else if (symbol === "^CNXIT") {
      newsQuery = { sector_market: "Nifty IT" };
    }

    // 🚀 Start Python movers in background (non-blocking)
    const pythonPath = path.join(__dirname, "..", "venv", "bin", "python");
    const scriptPath = path.join(__dirname, "..", "nse_movers.py");
    const moversPromise = new Promise((resolve) => {
      exec(`"${pythonPath}" "${scriptPath}" "${symbol}"`, { timeout: 15000 }, (error, stdout) => {
        if (error) {
          resolve({ gainers: [], losers: [] });
          return;
        }
        try {
          resolve(JSON.parse(stdout));
        } catch (e) {
          resolve({ gainers: [], losers: [] });
        }
      });
    });

    // 🚀 Fetch chart + quote + news in parallel (do NOT wait for Python)
    const [quote, chart, news] = await Promise.all([
      yahooFinance.quote(symbol),
      yahooFinance.chart(symbol, { period1: startDate, period2: endDate, interval: "1d" }),
      newsQuery ? FilteredNews.find(newsQuery)
        .select('Headline summary sentiment impact companies sector_market ingested_at _id')
        .sort({ ingested_at: -1 })
        .limit(10)
        .lean() : Promise.resolve([])
    ]);

    // ⏱️ Give movers at most 3s extra — return empty arrays if still running
    const movers = await Promise.race([
      moversPromise,
      new Promise((resolve) => setTimeout(() => resolve({ gainers: [], losers: [] }), 3000))
    ]);

    console.log(`✅ Chart for ${symbol}: timestamps=${chart.timestamps?.length ?? 0}, quotes=${chart.quotes?.length ?? 0}`);

    /*
    FINAL RESPONSE
    */
    const responseData = {

      indexName: quote.shortName,
      price: quote.regularMarketPrice,
      change: quote.regularMarketChange,
      changePercent: quote.regularMarketChangePercent,

chart: (chart.timestamps || []).map((t, i) => {

  const close = chart.quotes?.[i]?.close;

  if (!close) return null;

  return {
    close,
    date: new Date(t * 1000).toISOString()
  };

}).filter(Boolean),

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

    const nameMap = {
      "^GSPC": "S&P 500",
      "^DJI": "Dow Jones",
      "^IXIC": "NASDAQ",
      "^HSI": "Hang Seng",
      "^N225": "Nikkei 225",
    };

    const endDate = new Date();
    const startDate = new Date();
    startDate.setDate(endDate.getDate() - 30); // 30 days to always have data
    const chartOptions = { period1: startDate, period2: endDate, interval: "1d" };

    // 🚀 Fetch ALL quotes in parallel, then ALL charts in parallel
    // Per-symbol .catch() so one failure never kills the whole response
    const quotes = await Promise.all(
      globalSymbols.map((s) => yahooFinance.quote(s).catch(() => null))
    );
    const charts = await Promise.all(
      globalSymbols.map((s) =>
        yahooFinance.chart(s, chartOptions).catch(() => ({ quotes: [], timestamps: [] }))
      )
    );

    const data = globalSymbols.map((symbol, i) => {
      const q = quotes[i];
      const c = charts[i];
      console.log(`✅ Global ${symbol}: price=${q?.regularMarketPrice}, chartLen=${c?.quotes?.length ?? 0}`);
      return {
        symbol,
        name: nameMap[symbol],
        price: q?.regularMarketPrice ?? 0,
        chart: c?.quotes || [],
      };
    });

    cache.set(cacheKey, data);

    res.json(data);

  } catch (e) {

    console.log(e);

    res.status(500).json({
      error: "Failed global data"
    });

  }

});

/*
SECTOR INDEX DATA
*/
router.post("/sectors", async (req, res) => {
  try {
    const cacheKey = "sector_data";

    if (cache.has(cacheKey)) {
      console.log("⚡ Serving /sectors from cache");
      return res.json(cache.get(cacheKey));
    }

    const sEndDate = new Date();
    const sStartDate = new Date();
    sStartDate.setDate(sEndDate.getDate() - 30); // 30 days to always have data
    const sChartOptions = { period1: sStartDate, period2: sEndDate, interval: "1d" };

    // 🚀 Fetch ALL sector quotes in parallel, then ALL charts in parallel
    const sQuotes = await Promise.all(
      sectorSymbols.map(({ symbol }) =>
        yahooFinance.quote(symbol).catch(() => null)
      )
    );
    const sCharts = await Promise.all(
      sectorSymbols.map(({ symbol }) =>
        yahooFinance.chart(symbol, sChartOptions).catch(() => null)
      )
    );

    const data = sectorSymbols.map(({ symbol, name }, i) => {
      const quote = sQuotes[i];
      const chart = sCharts[i];
      if (!quote || !chart) return { symbol, name, price: 0, chart: [] };
      return {
        symbol,
        name,
        price: quote.regularMarketPrice || 0,
        chart: (chart.quotes || []).map((q, j) => ({
          close: q.close,
          date: chart.timestamps?.[j],
        })),
      };
    });

    cache.set(cacheKey, data);
    res.json(data);
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: "Failed to fetch sector data" });
  }
});


module.exports = router;