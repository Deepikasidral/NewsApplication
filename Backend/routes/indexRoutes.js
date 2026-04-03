const express = require("express");
const router = express.Router();
const FilteredNews = require("../models/filteredNews");

const YahooFinance = require("yahoo-finance2").default;
const yahooFinance = new YahooFinance({
  suppressNotices: ['yahooSurvey'],
  validation: {
    logErrors: true
  }
});

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

  const { symbol } = req.body;

  console.log("🔥 /data API HIT - Symbol:", symbol);

  try {

    if (!symbol) {
      return res.status(400).json({ error: "Symbol required" });
    }

    const cacheKey = `data_${symbol}`;

    if (cache.has(cacheKey)) {
      console.log(`⚡ Serving ${symbol} from cache`);
      return res.json(cache.get(cacheKey));
    }

    console.log(`🆕 Cache miss for ${symbol}, fetching fresh data...`);

    const endDate = new Date();
    const startDate = new Date();
    startDate.setDate(endDate.getDate() - 22);

    let newsQuery;
    if (symbol === "^NSEI") {
      // For NSEI, get all Indian market news (not global, not commodities)
      newsQuery = {
        global: false,
        commodities: false
      };
    } else if (symbol === "^NSEBANK") {
      newsQuery = {
        sector_market: "Nifty Bank"
      };
    } else if (symbol === "^CNXIT") {
      newsQuery = {
        sector_market: "Nifty IT"
      };
    }

    console.log("📰 News query:", JSON.stringify(newsQuery));

    console.log("🔥 Starting data fetch for:", symbol);

    // Map symbol to constituent symbols for movers
    const constituentMap = {
      "^NSEI": ["RELIANCE.NS", "TCS.NS", "HDFCBANK.NS", "INFY.NS", "ICICIBANK.NS", "HINDUNILVR.NS", "ITC.NS", "SBIN.NS", "BHARTIARTL.NS", "KOTAKBANK.NS",
                "LT.NS", "AXISBANK.NS", "ASIANPAINT.NS", "MARUTI.NS", "SUNPHARMA.NS", "TITAN.NS", "BAJFINANCE.NS", "ULTRACEMCO.NS", "NESTLEIND.NS", "WIPRO.NS",
                "HCLTECH.NS", "TECHM.NS", "POWERGRID.NS", "NTPC.NS", "ONGC.NS", "TATASTEEL.NS", "COALINDIA.NS", "BAJAJFINSV.NS", "M&M.NS", "ADANIPORTS.NS"],
      "^NSEBANK": ["HDFCBANK.NS", "ICICIBANK.NS", "SBIN.NS", "AXISBANK.NS", "KOTAKBANK.NS", "INDUSINDBK.NS", "BANDHANBNK.NS", "FEDERALBNK.NS", "IDFCFIRSTB.NS", "PNB.NS"],
      "^CNXIT": ["TCS.NS", "INFY.NS", "WIPRO.NS", "HCLTECH.NS", "TECHM.NS", "LTIM.NS", "PERSISTENT.NS", "COFORGE.NS", "MPHASIS.NS", "LTTS.NS"]
    };

    // 🚀 PARALLEL EXECUTION with error handling
    const [quote, chart, movers, news] = await Promise.allSettled([
      yahooFinance.quote(symbol).catch(err => {
        console.log("❌ Quote error:", err.message);
        return null;
      }),
      yahooFinance.chart(symbol, {
        period1: startDate,
        period2: endDate,
        interval: "1d"
      }).then(result => {
        console.log("📈 Chart data received:", {
          timestamps: result.timestamps?.length || 0,
          quotes: result.quotes?.length || 0,
          meta: result.meta ? 'present' : 'missing'
        });
        return result;
      }).catch(err => {
        console.log("❌ Chart error:", err.message);
        return { timestamps: [], quotes: [] };
      }),
      // Fetch movers using Yahoo Finance instead of Python
      (async () => {
        try {
          const constituents = constituentMap[symbol] || constituentMap["^NSEI"];
          console.log(`📈 Fetching movers for ${constituents.length} stocks...`);

          const quotes = await Promise.allSettled(
            constituents.map(s => yahooFinance.quote(s).catch(() => null))
          );

          const stocks = quotes
            .filter(r => r.status === 'fulfilled' && r.value)
            .map(r => r.value)
            .filter(q => q.regularMarketChangePercent !== undefined)
            .map(q => ({
              symbol: q.symbol.replace('.NS', ''),
              lastPrice: q.regularMarketPrice || 0,
              pChange: q.regularMarketChangePercent || 0
            }));

          const gainers = stocks
            .filter(s => s.pChange > 0)
            .sort((a, b) => b.pChange - a.pChange)
            .slice(0, 5);

          const losers = stocks
            .filter(s => s.pChange < 0)
            .sort((a, b) => a.pChange - b.pChange)
            .slice(0, 5);

          console.log("✅ Movers fetched:", gainers.length, "gainers,", losers.length, "losers");
          return { gainers, losers };
        } catch (err) {
          console.log("❌ Movers fetch error:", err.message);
          return { gainers: [], losers: [] };
        }
      })(),
      newsQuery ? FilteredNews.find(newsQuery)
        .select('Headline summary sentiment impact companies sector_market ingested_at _id')
        .sort({ ingested_at: -1 })
        .limit(10)
        .lean()
        .then(result => {
          console.log("📰 News fetched:", result.length, "articles");
          return result;
        })
        .catch(err => {
          console.log("❌ News fetch error:", err.message);
          return [];
        }) : Promise.resolve([])
    ]);

    // Extract results with fallbacks
    const quoteData = quote.status === 'fulfilled' && quote.value ? quote.value : { shortName: 'N/A', regularMarketPrice: 0, regularMarketChange: 0, regularMarketChangePercent: 0 };
    const chartData = chart.status === 'fulfilled' && chart.value ? chart.value : { timestamps: [], quotes: [] };
    const moversData = movers.status === 'fulfilled' ? movers.value : { gainers: [], losers: [] };
    const newsData = news.status === 'fulfilled' ? news.value : [];

    console.log("✅ Data fetch complete for", symbol, ":", {
      quote: !!quoteData.regularMarketPrice,
      chartPoints: chartData.timestamps?.length || 0,
      gainers: moversData.gainers?.length || 0,
      losers: moversData.losers?.length || 0,
      news: newsData.length
    });


    /*
    FINAL RESPONSE
    */
    // Handle chart data - Yahoo Finance might return quotes without timestamps
    let chartPoints = [];
    if (chartData.quotes && chartData.quotes.length > 0) {
      chartPoints = chartData.quotes.map((q, i) => {
        if (!q || !q.close) return null;
        // Use timestamp from quote object or from timestamps array
        const timestamp = q.date || (chartData.timestamps && chartData.timestamps[i]);
        if (!timestamp) return null;

        return {
          close: q.close,
          date: typeof timestamp === 'number' ? new Date(timestamp * 1000).toISOString() : new Date(timestamp).toISOString()
        };
      }).filter(Boolean);
    }

    console.log("📉 Chart processing:", {
      rawTimestamps: chartData.timestamps?.length || 0,
      rawQuotes: chartData.quotes?.length || 0,
      processedPoints: chartPoints.length
    });

    const responseData = {
      indexName: quoteData.shortName,
      price: quoteData.regularMarketPrice,
      change: quoteData.regularMarketChange,
      changePercent: quoteData.regularMarketChangePercent,
      chart: chartPoints,
      gainers: moversData.gainers || [],
      losers: moversData.losers || [],
      news: newsData
    };

    console.log(`💾 Caching data for ${symbol}`);
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

    console.log("🌍 Starting global indices fetch...");

    const data = await Promise.allSettled(
      globalSymbols.map(async (symbol) => {
        try {
          const quote = await yahooFinance.quote(symbol);

          const endDate = new Date();
          const startDate = new Date();
          startDate.setDate(endDate.getDate() - 22);

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
        } catch (err) {
          console.error(`❌ Error fetching ${symbol}:`, err.message);
          return null;
        }
      })
    );

    const validData = data
      .filter(result => result.status === 'fulfilled' && result.value !== null)
      .map(result => result.value);

    console.log("✅ Global indices fetched:", validData.length, "out of", globalSymbols.length);

    cache.set(cacheKey, validData);
    res.json(validData);
  } catch (e) {
    console.error("❌ Global fetch error:", e);
    res.status(500).json({ error: "Failed global data" });
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

    console.log("🏭 Starting sector indices fetch...");

    const data = await Promise.allSettled(
      sectorSymbols.map(async ({ symbol, name }) => {
        try {
          const quote = await yahooFinance.quote(symbol);

          const endDate = new Date();
          const startDate = new Date();
          startDate.setDate(endDate.getDate() - 22);

          const chart = await yahooFinance.chart(symbol, {
            period1: startDate,
            period2: endDate,
            interval: "1d",
          });

          // Process chart data properly
          const chartPoints = (chart.quotes || []).map((q, i) => {
            if (!q || !q.close) return null;
            const timestamp = q.date || (chart.timestamps && chart.timestamps[i]);
            if (!timestamp) return null;

            return {
              close: q.close,
              date: typeof timestamp === 'number' ? timestamp : new Date(timestamp).getTime() / 1000
            };
          }).filter(Boolean);

          console.log(`✅ Fetched ${symbol}: ${chartPoints.length} chart points`);

          return {
            symbol,
            name,
            price: quote.regularMarketPrice || 0,
            chart: chartPoints,
          };
        } catch (err) {
          console.error(`❌ Error fetching ${symbol}:`, err.message);
          return { symbol, name, price: 0, chart: [] };
        }
      })
    );

    const validData = data
      .filter(result => result.status === 'fulfilled')
      .map(result => result.value);

    console.log("✅ Sector indices fetched:", validData.length, "out of", sectorSymbols.length);

    cache.set(cacheKey, validData);
    res.json(validData);
  } catch (e) {
    console.error("❌ Sector fetch error:", e);
    res.status(500).json({ error: "Failed to fetch sector data" });
  }
});


module.exports = router;