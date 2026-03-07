const express = require("express");
const router = express.Router();
const YahooFinance = require("yahoo-finance2").default;
const yahooFinance = new YahooFinance();
const NodeCache = require("node-cache");
const cache = new NodeCache({ stdTTL: 60 });

router.post("/batch", async (req, res) => {
  try {
    const { symbols } = req.body;

    if (!symbols || !Array.isArray(symbols) || symbols.length === 0) {
      return res.status(400).json({ error: "Symbols array required" });
    }

    const limitedSymbols = symbols.slice(0, 50);
    const results = {};

    const uncachedSymbols = [];
    for (const symbol of limitedSymbols) {
      const cacheKey = `stock_${symbol}`;
      if (cache.has(cacheKey)) {
        results[symbol] = cache.get(cacheKey);
      } else {
        uncachedSymbols.push(symbol);
      }
    }

    if (uncachedSymbols.length > 0) {
      const promises = uncachedSymbols.map(async (symbol) => {
        try {
          const quote = await yahooFinance.quote(`${symbol}.NS`);
          const currentPrice = quote.regularMarketPrice || 0;
          const previousClose = quote.regularMarketPreviousClose || currentPrice;
          const change = currentPrice - previousClose;
          const changePercent = previousClose !== 0 ? (change / previousClose) * 100 : 0;

          const data = {
            price: currentPrice.toFixed(2),
            change: change.toFixed(2),
            changePercent: changePercent.toFixed(2),
          };

          cache.set(`stock_${symbol}`, data);
          return { symbol, data };
        } catch (err) {
          console.error(`Error fetching ${symbol}:`, err.message);
          return { symbol, data: null };
        }
      });

      const fetchedData = await Promise.all(promises);
      fetchedData.forEach(({ symbol, data }) => {
        results[symbol] = data;
      });
    }

    res.json({ success: true, data: results });
  } catch (error) {
    console.error("Batch stock fetch error:", error);
    res.status(500).json({ error: "Failed to fetch stock prices" });
  }
});

module.exports = router;
