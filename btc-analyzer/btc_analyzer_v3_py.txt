# btc_analyzer_v3.py -- ADVANCED VERSION
import pandas as pd
import numpy as np
from datetime import datetime
import requests

print("=" * 60)
print("BTC ANALYZER v3 -- WORKING")
print("=" * 60)

def get_binance_klines(symbol="BTCUSDT", interval="15m", limit=500):
    url = "https://api.binance.com/api/v3/klines"
    params = {"symbol": symbol, "interval": interval, "limit": limit}
    try:
        response = requests.get(url, params=params, timeout=30)
        response.raise_for_status()
        data = response.json()
        df = pd.DataFrame(data, columns=[
            "timestamp", "open", "high", "low", "close", "volume",
            "close_time", "quote_volume", "trades", "taker_buy_base",
            "taker_buy_quote", "ignore"
        ])
        df["timestamp"] = pd.to_datetime(df["timestamp"], unit="ms")
        df.set_index("timestamp", inplace=True)
        for col in ["open", "high", "low", "close", "volume"]:
            df[col] = df[col].astype(float)
        return df[["open", "high", "low", "close", "volume"]]
    except Exception as e:
        print(f"API Error: {e}")
        return None

df = get_binance_klines("BTCUSDT", "15m", 500)

if df is None:
    print("Using synthetic data...")
    dates = pd.date_range(end=datetime.now(), periods=500, freq="15min")
    np.random.seed(42)
    prices = 65000 + np.cumsum(np.random.randn(500) * 100)
    df = pd.DataFrame({
        "open": (prices + np.random.randn(500) * 50).astype(float),
        "high": (prices + np.random.randn(500) * 100 + 50).astype(float),
        "low": (prices - np.random.randn(500) * 100 - 50).astype(float),
        "close": prices.astype(float),
        "volume": np.random.randint(100, 1000, 500).astype(float)
    }, index=dates)

# INDICATORS
df["ema_9"] = df["close"].ewm(span=9, adjust=False).mean()
df["ema_21"] = df["close"].ewm(span=21, adjust=False).mean()
df["sma_50"] = df["close"].rolling(window=50).mean()
df["sma_200"] = df["close"].rolling(window=200).mean()

delta = df["close"].diff()
gain = (delta.where(delta > 0, 0)).rolling(window=14).mean()
loss = (-delta.where(delta < 0, 0)).rolling(window=14).mean()
rs = gain / loss
df["rsi"] = 100 - (100 / (1 + rs))

ema_12 = df["close"].ewm(span=12, adjust=False).mean()
ema_26 = df["close"].ewm(span=26, adjust=False).mean()
df["macd"] = ema_12 - ema_26
df["macd_signal"] = df["macd"].ewm(span=9, adjust=False).mean()

df["bb_middle"] = df["close"].rolling(window=20).mean()
bb_std = df["close"].rolling(window=20).std()
df["bb_upper"] = df["bb_middle"] + (bb_std * 2)
df["bb_lower"] = df["bb_middle"] - (bb_std * 2)

df["trend"] = "neutral"
df.loc[(df["close"] > df["sma_200"]) & (df["sma_50"] > df["sma_200"]), "trend"] = "uptrend"
df.loc[(df["close"] < df["sma_200"]) & (df["sma_50"] < df["sma_200"]), "trend"] = "downtrend"

# SIGNALS
df["signal"] = 0.0
df["signal_type"] = ""
df["reasons"] = ""

for i in range(200, len(df)):
    score = 0.0
    reasons = []
    signal_type = ""
    current = df.iloc[i]
    prev = df.iloc[i-1]

    if current["ema_9"] > current["ema_21"] and prev["ema_9"] <= prev["ema_21"]:
        score += 2.0; reasons.append("EMA9 crossed EMA21 UP")
    elif current["ema_9"] < current["ema_21"] and prev["ema_9"] >= prev["ema_21"]:
        score -= 2.0; reasons.append("EMA9 crossed EMA21 DOWN")

    if current["trend"] == "uptrend":
        score += 1.5; reasons.append("Trend UP")
    elif current["trend"] == "downtrend":
        score -= 1.5; reasons.append("Trend DOWN")

    if current["rsi"] < 30:
        score += 1.5; reasons.append(f"RSI oversold ({current['rsi']:.1f})")
    elif current["rsi"] > 70:
        score -= 1.5; reasons.append(f"RSI overbought ({current['rsi']:.1f})")

    if current["macd"] > current["macd_signal"] and prev["macd"] <= prev["macd_signal"]:
        score += 1.5; reasons.append("MACD crossed UP")
    elif current["macd"] < current["macd_signal"] and prev["macd"] >= prev["macd_signal"]:
        score -= 1.5; reasons.append("MACD crossed DOWN")

    if current["close"] < current["bb_lower"]:
        score += 1.0; reasons.append("Price below BB lower")
    elif current["close"] > current["bb_upper"]:
        score -= 1.0; reasons.append("Price above BB upper")

    if score >= 3.0: signal_type = "STRONG_BUY"
    elif score >= 1.5: signal_type = "BUY"
    elif score <= -3.0: signal_type = "STRONG_SELL"
    elif score <= -1.5: signal_type = "SELL"
    else: signal_type = "NEUTRAL"

    df.iloc[i, df.columns.get_loc("signal")] = score
    df.iloc[i, df.columns.get_loc("signal_type")] = signal_type
    df.iloc[i, df.columns.get_loc("reasons")] = " | ".join(reasons)

last = df.iloc[-1]
print(f"\\nPrice: ${last['close']:,.2f}")
print(f"Signal: {last['signal_type']} (Score: {last['signal']:.1f})")
print(f"Trend: {last['trend'].upper()}")
print(f"RSI: {last['rsi']:.1f}")
print(f"\\nReasons:")
for r in last['reasons'].split(" | "):
    if r.strip(): print(f"  - {r}")

print("\\n" + "=" * 60)
print("DONE")
print("=" * 60)
