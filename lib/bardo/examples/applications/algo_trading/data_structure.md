# Algorithmic Trading Data Structure

This document outlines the structure for storing historical market data for forex and cryptocurrency trading.

## Overview

All historical data will be stored in the `/priv/market_data/` directory using the following structure:

```
/priv/market_data/
├── forex/                      # Forex market data
│   ├── oanda/                  # OANDA data source
│   │   ├── EURUSD/             # Currency pair
│   │   │   ├── M1/             # 1-minute timeframe
│   │   │   ├── M5/             # 5-minute timeframe
│   │   │   ├── M15/            # 15-minute timeframe
│   │   │   ├── M30/            # 30-minute timeframe
│   │   │   ├── H1/             # 1-hour timeframe
│   │   │   ├── H4/             # 4-hour timeframe
│   │   │   ├── D1/             # Daily timeframe
│   │   ├── GBPUSD/
│   │   ├── USDJPY/
│   │   └── ...
│   └── other_sources/          # For future forex data sources
├── crypto/                     # Cryptocurrency market data
│   ├── gemini/                 # GEMINI data source
│   │   ├── BTCUSD/             # Currency pair
│   │   │   ├── M1/             # 1-minute timeframe
│   │   │   ├── M5/             # 5-minute timeframe
│   │   │   └── ...
│   │   ├── ETHUSD/
│   │   └── ...
│   └── other_sources/          # For future crypto data sources
└── cache/                      # Cache for temporarily stored data
    ├── forex/
    └── crypto/
```

## File Format

Data files will be stored in two formats:

1. **CSV format**: For human readability and compatibility with other tools
   - Filename format: `{PAIR}_{TIMEFRAME}_{START_DATE}_{END_DATE}.csv`
   - Example: `EURUSD_M15_20250101_20250131.csv`

2. **Binary format**: For efficient storage and faster loading
   - Filename format: `{PAIR}_{TIMEFRAME}_{START_DATE}_{END_DATE}.dat`
   - Example: `EURUSD_M15_20250101_20250131.dat`

## CSV Structure

CSV files will have the following column structure:

```
timestamp,open,high,low,close,volume,spread
2025-01-01T00:00:00.000Z,1.2345,1.2350,1.2340,1.2348,1000,0.0002
```

- `timestamp`: ISO 8601 format timestamp (UTC)
- `open`: Opening price for the period
- `high`: Highest price during the period
- `low`: Lowest price during the period
- `close`: Closing price for the period
- `volume`: Trading volume
- `spread`: Average spread during the period (when available)

## Metadata

Each data directory will contain a `metadata.json` file with information about the data:

```json
{
  "pair": "EURUSD",
  "timeframe": "M15",
  "data_source": "OANDA",
  "start_date": "2025-01-01T00:00:00.000Z",
  "end_date": "2025-01-31T23:59:59.999Z",
  "total_records": 2976,
  "last_updated": "2025-02-01T10:15:00.000Z"
}
```

## Data Integrity

To ensure data integrity:

1. Each file will include a checksum in the metadata
2. Data validation will check for gaps and anomalies
3. Automatic error detection for corrupted files