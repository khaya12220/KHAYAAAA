
//+------------------------------------------------------------------+
//|                         KHAYA.mq5                                 |
//|              Automated Multi-Market Scalping EA                   |
//|                         Phases 1-8                               |
//+------------------------------------------------------------------+
#property strict
#property version   "1.08"
#property description "KHAYA Multi-Market Scalping EA - Phases 1-8"
#include <Trade/Trade.mqh>

//====================================================================
// INPUTS
//====================================================================

input string InpEAName = "KHAYA";

input ulong InpMagicNumber = 26090801;

input bool InpAutoTrading = false;


//====================================================================
// TRADING SESSION
//====================================================================

input int InpStartHour = 6;

input int InpStartMinute = 0;

input int InpEndHour = 23;

input int InpEndMinute = 0;


//====================================================================
// MARKET WATCH
//====================================================================

input bool InpScanMarketWatch = true;

input int InpScanIntervalMilliseconds = 500;


//====================================================================
// TIMEFRAMES
//====================================================================

input ENUM_TIMEFRAMES InpFastTimeframe = PERIOD_M1;

input ENUM_TIMEFRAMES InpConfirmTimeframe = PERIOD_M5;

input ENUM_TIMEFRAMES InpTrendTimeframe = PERIOD_M15;


//====================================================================
// TREND ENGINE
//====================================================================

input int InpFastEMA = 9;

input int InpSlowEMA = 21;

input int InpTrendEMA = 50;


//====================================================================
// VOLATILITY ENGINE
//====================================================================

input int InpATRPeriod = 14;

input int InpATRAverageBars = 50;

input double InpHighVolatilityRatio = 1.50;

input double InpLowVolatilityRatio = 0.50;


//====================================================================
// SPREAD PROTECTION
//====================================================================

input double InpMaxSpreadPoints = 0.0;


//====================================================================
// GLOBAL STATE
//====================================================================

bool g_khayaInitialized = false;

bool g_sessionOpen = false;

bool g_weekendClosed = false;

bool g_marketDataReady = false;

ulong g_lastScanTime = 0;

datetime g_lastStatusTime = 0;

int g_marketWatchCount = 0;

int g_readySymbolCount = 0;

int g_bullishSymbols = 0;

int g_bearishSymbols = 0;


//====================================================================
// MARKET REGIME
//====================================================================

enum KHMarketRegime
{
   KH_REGIME_NEUTRAL = 0,
   KH_REGIME_TREND_UP,
   KH_REGIME_TREND_DOWN,
   KH_REGIME_RANGE,
   KH_REGIME_HIGH_VOLATILITY,
   KH_REGIME_LOW_VOLATILITY
};


//====================================================================
// TIMEFRAME DIRECTION
//====================================================================

enum KHTFDirection
{
   KH_TF_NEUTRAL = 0,
   KH_TF_BULLISH,
   KH_TF_BEARISH
};


//====================================================================
// MARKET DATA
//====================================================================

struct KHMarketData
{
   string symbol;

   bool valid;

   double bid;
   double ask;

   double spreadPoints;

   double point;

   int digits;

   double tickSize;

   double tickValue;

   double volumeMin;

   double volumeMax;

   double volumeStep;

   datetime currentBarTime;

   datetime previousBarTime;

   double currentOpen;

   double currentHigh;

   double currentLow;

   double currentClose;

   double previousOpen;

   double previousHigh;

   double previousLow;

   double previousClose;

   long tickVolume;
};


//====================================================================
// REGIME DATA
//====================================================================

struct KHRegimeData
{
   KHMarketRegime regime;

   double fastEMA;

   double slowEMA;

   double trendEMA;

   double atr;

   double atrAverage;

   double volatilityRatio;

   double emaSlope;

   int strength;
};


//====================================================================
// TIMEFRAME DATA
//====================================================================

struct KHTFData
{
   ENUM_TIMEFRAMES timeframe;

   KHTFDirection direction;

   double fastEMA;

   double slowEMA;

   double trendEMA;

   double closePrice;

   int strength;
};


//====================================================================
// MULTI-TIMEFRAME DATA
//====================================================================

struct KHMultiTFData
{
   KHTFData fast;

   KHTFData confirm;

   KHTFData trend;

   int bullishScore;

   int bearishScore;

   int alignmentScore;

   KHTFDirection overallDirection;
};


//====================================================================
// VPS / MOBILE STATUS
//====================================================================

struct KHSystemStatus
{
   bool eaRunning;

   bool autoTrading;

   bool sessionOpen;

   bool weekendClosed;

   bool marketConnected;

   bool tradingAllowed;

   int symbolsMonitored;

   int symbolsReady;

   int bullishSymbols;

   int bearishSymbols;

   datetime serverTime;
};


//====================================================================
// EXPERT INITIALIZATION
//====================================================================

int OnInit()
{
   g_khayaInitialized = true;

   EventSetTimer(1);

   Print("==================================================");

   Print("KHAYA INITIALIZED");

   Print("Version: 1.08");

   Print(
      "Magic Number: ",
      InpMagicNumber
   );

   Print(
      "Automatic Trading: ",
      InpAutoTrading ? "ON" : "OFF"
   );

   Print(
      "Trading Session: ",
      InpStartHour,
      ":",
      InpStartMinute,
      " - ",
      InpEndHour,
      ":",
      InpEndMinute
   );

   Print(
      "Fast Timeframe: ",
      EnumToString(
         InpFastTimeframe
      )
   );

   Print(
      "Confirm Timeframe: ",
      EnumToString(
         InpConfirmTimeframe
      )
   );

   Print(
      "Trend Timeframe: ",
      EnumToString(
         InpTrendTimeframe
      )
   );

   Print("==================================================");

   UpdateKHSession();

   return(INIT_SUCCEEDED);
}


//====================================================================
// EXPERT DEINITIALIZATION
//====================================================================

void OnDeinit(
   const int reason
)
{
   EventKillTimer();

   g_khayaInitialized = false;

   Comment("");

   Print("KHAYA DEINITIALIZED");

   Print(
      "Reason: ",
      reason
   );
}


//====================================================================
// TICK EVENT
//====================================================================

void OnTick()
{
   if(!g_khayaInitialized)
      return;

   UpdateKHSession();

   RunKHMarketScanner();

   RunKHAnalysis();
   RunKHMasterTradingEngine();
}


//====================================================================
// TIMER EVENT
//====================================================================

void OnTimer()
{
   if(!g_khayaInitialized)
      return;

   UpdateKHSession();

   RunKHMarketScanner();

   UpdateKHMobileStatus();
   RunKHMasterTradingEngine();
}


//====================================================================
// SESSION ENGINE
//====================================================================

void UpdateKHSession()
{
   MqlDateTime currentTime;

   TimeToStruct(
      TimeCurrent(),
      currentTime
   );


   int currentMinutes =
      currentTime.hour * 60 +
      currentTime.min;


   int startMinutes =
      InpStartHour * 60 +
      InpStartMinute;


   int endMinutes =
      InpEndHour * 60 +
      InpEndMinute;


   g_weekendClosed =
      (
         currentTime.day_of_week == 0 ||
         currentTime.day_of_week == 6
      );


   if(g_weekendClosed)
   {
      g_sessionOpen = false;

      return;
   }


   if(startMinutes < endMinutes)
   {
      g_sessionOpen =
         (
            currentMinutes >= startMinutes &&
            currentMinutes < endMinutes
         );
   }
   else
   {
      g_sessionOpen =
         (
            currentMinutes >= startMinutes ||
            currentMinutes < endMinutes
         );
   }
}


//====================================================================
// MARKET WATCH SCANNER
//====================================================================

void RunKHMarketScanner()
{
   if(!InpScanMarketWatch)
      return;


   ulong currentTime =
      GetTickCount64();


   ulong scanInterval =
      (ulong)MathMax(
         100,
         InpScanIntervalMilliseconds
      );


   if(
      g_lastScanTime > 0 &&
      currentTime - g_lastScanTime <
      scanInterval
   )
   {
      return;
   }


   g_lastScanTime =
      currentTime;


   int totalSymbols =
      SymbolsTotal(true);


   g_marketWatchCount = 0;

   g_readySymbolCount = 0;


   for(
      int index = 0;
      index < totalSymbols;
      index++
   )
   {
      string symbol =
         SymbolName(
            index,
            true
         );


      if(symbol == "")
         continue;


      g_marketWatchCount++;


      MqlTick tick;


      if(
         !SymbolInfoTick(
            symbol,
            tick
         )
      )
      {
         continue;
      }


      if(
         tick.bid <= 0 ||
         tick.ask <= 0
      )
      {
         continue;
      }


      if(
         tick.ask < tick.bid
      )
      {
         continue;
      }


      g_readySymbolCount++;
   }
}


//====================================================================
// MARKET DATA
//====================================================================

bool GetKHMarketData(
   string symbol,
   KHMarketData &data
)
{
   data.symbol = symbol;

   data.valid = false;


   data.bid =
      SymbolInfoDouble(
         symbol,
         SYMBOL_BID
      );


   data.ask =
      SymbolInfoDouble(
         symbol,
         SYMBOL_ASK
      );


   data.point =
      SymbolInfoDouble(
         symbol,
         SYMBOL_POINT
      );


   data.digits =
      (int)SymbolInfoInteger(
         symbol,
         SYMBOL_DIGITS
      );


   data.tickSize =
      SymbolInfoDouble(
         symbol,
         SYMBOL_TRADE_TICK_SIZE
      );


   data.tickValue =
      SymbolInfoDouble(
         symbol,
         SYMBOL_TRADE_TICK_VALUE
      );


   data.volumeMin =
      SymbolInfoDouble(
         symbol,
         SYMBOL_VOLUME_MIN
      );


   data.volumeMax =
      SymbolInfoDouble(
         symbol,
         SYMBOL_VOLUME_MAX
      );


   data.volumeStep =
      SymbolInfoDouble(
         symbol,
         SYMBOL_VOLUME_STEP
      );


   if(
      data.point <= 0 ||
      data.bid <= 0 ||
      data.ask <= 0
   )
   {
      return false;
   }


   if(data.ask < data.bid)
      return false;


   data.spreadPoints =
      (
         data.ask -
         data.bid
      ) /
      data.point;


   MqlRates rates[];

   ArraySetAsSeries(
      rates,
      true
   );


   int copied =
      CopyRates(
         symbol,
         PERIOD_M1,
         0,
         2,
         rates
      );


   if(copied < 2)
      return false;


   data.currentBarTime =
      rates[0].time;

   data.currentOpen =
      rates[0].open;

   data.currentHigh =
      rates[0].high;

   data.currentLow =
      rates[0].low;

   data.currentClose =
      rates[0].close;

   data.tickVolume =
      (long)rates[0].tick_volume;


   data.previousBarTime =
      rates[1].time;

   data.previousOpen =
      rates[1].open;

   data.previousHigh =
      rates[1].high;

   data.previousLow =
      rates[1].low;

   data.previousClose =
      rates[1].close;


   data.valid = true;


   return true;
}


//====================================================================
// EMA
//====================================================================

double GetKHMovingAverage(
   string symbol,
   ENUM_TIMEFRAMES timeframe,
   int period,
   int shift
)
{
   if(period <= 0)
      return 0.0;


   int handle =
      iMA(
         symbol,
         timeframe,
         period,
         0,
         MODE_EMA,
         PRICE_CLOSE
      );


   if(handle == INVALID_HANDLE)
      return 0.0;


   double buffer[];

   ArraySetAsSeries(
      buffer,
      true
   );


   int copied =
      CopyBuffer(
         handle,
         0,
         shift,
         1,
         buffer
      );


   IndicatorRelease(handle);


   if(copied < 1)
      return 0.0;


   return buffer[0];
}


//====================================================================
// ATR
//====================================================================

double GetKHATRValue(
   string symbol,
   ENUM_TIMEFRAMES timeframe,
   int period,
   int shift
)
{
   if(period <= 0)
      return 0.0;


   int handle =
      iATR(
         symbol,
         timeframe,
         period
      );


   if(handle == INVALID_HANDLE)
      return 0.0;


   double buffer[];

   ArraySetAsSeries(
      buffer,
      true
   );


   int copied =
      CopyBuffer(
         handle,
         0,
         shift,
         1,
         buffer
      );


   IndicatorRelease(handle);


   if(copied < 1)
      return 0.0;


   return buffer[0];
}


//====================================================================
// ATR AVERAGE
//====================================================================

double GetKHATRAverage(
   string symbol,
   ENUM_TIMEFRAMES timeframe,
   int period,
   int bars
)
{
   if(
      period <= 0 ||
      bars <= 0
   )
   {
      return 0.0;
   }


   int handle =
      iATR(
         symbol,
         timeframe,
         period
      );


   if(handle == INVALID_HANDLE)
      return 0.0;


   double buffer[];

   ArraySetAsSeries(
      buffer,
      true
   );


   int copied =
      CopyBuffer(
         handle,
         0,
         1,
         bars,
         buffer
      );


   IndicatorRelease(handle);


   if(copied <= 0)
      return 0.0;


   double total = 0.0;


   for(
      int index = 0;
      index < copied;
      index++
   )
   {
      total += buffer[index];
   }


   return total / copied;
}


//====================================================================
// MARKET REGIME ENGINE
//====================================================================

bool AnalyzeKHMarketRegime(
   string symbol,
   KHRegimeData &regime
)
{
   regime.regime =
      KH_REGIME_NEUTRAL;

   regime.fastEMA = 0.0;

   regime.slowEMA = 0.0;

   regime.trendEMA = 0.0;

   regime.atr = 0.0;

   regime.atrAverage = 0.0;

   regime.volatilityRatio = 0.0;

   regime.emaSlope = 0.0;

   regime.strength = 0;


   regime.fastEMA =
      GetKHMovingAverage(
         symbol,
         InpFastTimeframe,
         InpFastEMA,
         0
      );


   regime.slowEMA =
      GetKHMovingAverage(
         symbol,
         InpFastTimeframe,
         InpSlowEMA,
         0
      );


   regime.trendEMA =
      GetKHMovingAverage(
         symbol,
         InpFastTimeframe,
         InpTrendEMA,
         0
      );


   regime.atr =
      GetKHATRValue(
         symbol,
         InpFastTimeframe,
         InpATRPeriod,
         0
      );


   regime.atrAverage =
      GetKHATRAverage(
         symbol,
         InpFastTimeframe,
         InpATRPeriod,
         InpATRAverageBars
      );


   if(
      regime.fastEMA <= 0 ||
      regime.slowEMA <= 0 ||
      regime.trendEMA <= 0 ||
      regime.atr <= 0 ||
      regime.atrAverage <= 0
   )
   {
      return false;
   }


   regime.volatilityRatio =
      regime.atr /
      regime.atrAverage;


   double previousFastEMA =
      GetKHMovingAverage(
         symbol,
         InpFastTimeframe,
         InpFastEMA,
         1
      );


   if(previousFastEMA > 0)
   {
      regime.emaSlope =
         regime.fastEMA -
         previousFastEMA;
   }


   if(
      regime.volatilityRatio >=
      InpHighVolatilityRatio
   )
   {
      regime.regime =
         KH_REGIME_HIGH_VOLATILITY;

      regime.strength = 80;

      return true;
   }


   if(
      regime.volatilityRatio <=
      InpLowVolatilityRatio
   )
   {
      regime.regime =
         KH_REGIME_LOW_VOLATILITY;

      regime.strength = 60;

      return true;
   }


   double emaDistance =
      MathAbs(
         regime.fastEMA -
         regime.slowEMA
      );


   double minimumDistance =
      regime.atr * 0.10;


   if(
      regime.fastEMA >
      regime.slowEMA &&
      regime.slowEMA >
      regime.trendEMA &&
      regime.emaSlope > 0 &&
      emaDistance >= minimumDistance
   )
   {
      regime.regime =
         KH_REGIME_TREND_UP;

      regime.strength = 75;

      return true;
   }


   if(
      regime.fastEMA <
      regime.slowEMA &&
      regime.slowEMA <
      regime.trendEMA &&
      regime.emaSlope < 0 &&
      emaDistance >= minimumDistance
   )
   {
      regime.regime =
         KH_REGIME_TREND_DOWN;

      regime.strength = 75;

      return true;
   }


   if(
      emaDistance <
      minimumDistance
   )
   {
      regime.regime =
         KH_REGIME_RANGE;

      regime.strength = 55;

      return true;
   }


   return true;
}


//====================================================================
// TIMEFRAME ANALYSIS
//====================================================================

bool AnalyzeKHTimeframe(
   string symbol,
   ENUM_TIMEFRAMES timeframe,
   KHTFData &data
)
{
   data.timeframe =
      timeframe;

   data.direction =
      KH_TF_NEUTRAL;

   data.fastEMA = 0.0;

   data.slowEMA = 0.0;

   data.trendEMA = 0.0;

   data.closePrice = 0.0;

   data.strength = 0;


   data.fastEMA =
      GetKHMovingAverage(
         symbol,
         timeframe,
         InpFastEMA,
         0
      );


   data.slowEMA =
      GetKHMovingAverage(
         symbol,
         timeframe,
         InpSlowEMA,
         0
      );


   data.trendEMA =
      GetKHMovingAverage(
         symbol,
         timeframe,
         InpTrendEMA,
         0
      );


   data.closePrice =
      iClose(
         symbol,
         timeframe,
         0
      );


   if(
      data.fastEMA <= 0 ||
      data.slowEMA <= 0 ||
      data.trendEMA <= 0 ||
      data.closePrice <= 0
   )
   {
      return false;
   }


   if(
      data.fastEMA >
      data.slowEMA &&
      data.slowEMA >
      data.trendEMA &&
      data.closePrice >
      data.fastEMA
   )
   {
      data.direction =
         KH_TF_BULLISH;

      data.strength = 80;
   }
   else
   if(
      data.fastEMA <
      data.slowEMA &&
      data.slowEMA <
      data.trendEMA &&
      data.closePrice <
      data.fastEMA
   )
   {
      data.direction =
         KH_TF_BEARISH;

      data.strength = 80;
   }
   else
   if(
      data.fastEMA >
      data.slowEMA
   )
   {
      data.direction =
         KH_TF_BULLISH;

      data.strength = 55;
   }
   else
   if(
      data.fastEMA <
      data.slowEMA
   )
   {
      data.direction =
         KH_TF_BEARISH;

      data.strength = 55;
   }


   return true;
}


//====================================================================
// MULTI-TIMEFRAME ENGINE
//====================================================================

bool AnalyzeKHMultiTimeframe(
   string symbol,
   KHMultiTFData &data
)
{
   data.bullishScore = 0;

   data.bearishScore = 0;

   data.alignmentScore = 0;

   data.overallDirection =
      KH_TF_NEUTRAL;


   if(
      !AnalyzeKHTimeframe(
         symbol,
         InpFastTimeframe,
         data.fast
      )
   )
   {
      return false;
   }


   if(
      !AnalyzeKHTimeframe(
         symbol,
         InpConfirmTimeframe,
         data.confirm
      )
   )
   {
      return false;
   }


   if(
      !AnalyzeKHTimeframe(
         symbol,
         InpTrendTimeframe,
         data.trend
      )
   )
   {
      return false;
   }


   KHTFData frames[3];

   frames[0] = data.fast;

   frames[1] = data.confirm;

   frames[2] = data.trend;


   for(
      int index = 0;
      index < 3;
      index++
   )
   {
      if(
         frames[index].direction ==
         KH_TF_BULLISH
      )
      {
         data.bullishScore++;
      }
      else
      if(
         frames[index].direction ==
         KH_TF_BEARISH
      )
      {
         data.bearishScore++;
      }
   }


   data.alignmentScore =
      MathMax(
         data.bullishScore,
         data.bearishScore
      );


   if(
      data.bullishScore >= 2 &&
      data.bullishScore >
      data.bearishScore
   )
   {
      data.overallDirection =
         KH_TF_BULLISH;
   }
   else
   if(
      data.bearishScore >= 2 &&
      data.bearishScore >
      data.bullishScore
   )
   {
      data.overallDirection =
         KH_TF_BEARISH;
   }


   return true;
}


//====================================================================
// SPREAD CHECK
//====================================================================

bool KHSpreadAllowed(
   KHMarketData &data
)
{
   if(!data.valid)
      return false;


   if(InpMaxSpreadPoints <= 0)
      return true;


   return(
      data.spreadPoints <=
      InpMaxSpreadPoints
   );
}


//====================================================================
// MARKET CONNECTIVITY
//====================================================================

bool KHMarketConnected()
{
   MqlTick tick;


   if(
      !SymbolInfoTick(
         _Symbol,
         tick
      )
   )
   {
      return false;
   }


   return(
      tick.bid > 0 &&
      tick.ask > 0
   );
}


//====================================================================
// ANALYSIS ENGINE
//====================================================================

void RunKHAnalysis()
{
   if(!InpScanMarketWatch)
      return;


   if(g_marketWatchCount <= 0)
      return;


   g_bullishSymbols = 0;

   g_bearishSymbols = 0;


   int totalSymbols =
      SymbolsTotal(true);


   for(
      int index = 0;
      index < totalSymbols;
      index++
   )
   {
      string symbol =
         SymbolName(
            index,
            true
         );


      if(symbol == "")
         continue;


      KHMarketData marketData;


      if(
         !GetKHMarketData(
            symbol,
            marketData
         )
      )
      {
         continue;
      }


      if(
         !KHSpreadAllowed(
            marketData
         )
      )
      {
         continue;
      }


      KHRegimeData regime;


      if(
         !AnalyzeKHMarketRegime(
            symbol,
            regime
         )
      )
      {
         continue;
      }


      KHMultiTFData mtf;


      if(
         !AnalyzeKHMultiTimeframe(
            symbol,
            mtf
         )
      )
      {
         continue;
      }


      if(
         mtf.overallDirection ==
         KH_TF_BULLISH
      )
      {
         g_bullishSymbols++;
      }


      if(
         mtf.overallDirection ==
         KH_TF_BEARISH
      )
      {
         g_bearishSymbols++;
      }
   }


   g_marketDataReady = true;
}


//====================================================================
// DIRECTION NAME
//====================================================================

string KHTFDirectionToString(
   KHTFDirection direction
)
{
   if(
      direction ==
      KH_TF_BULLISH
   )
   {
      return "BULLISH";
   }


   if(
      direction ==
      KH_TF_BEARISH
   )
   {
      return "BEARISH";
   }


   return "NEUTRAL";
}


//====================================================================
// REGIME NAME
//====================================================================

string KHRegimeToString(
   KHMarketRegime regime
)
{
   switch(regime)
   {
      case KH_REGIME_TREND_UP:
         return "TREND UP";

      case KH_REGIME_TREND_DOWN:
         return "TREND DOWN";

      case KH_REGIME_RANGE:
         return "RANGE";

      case KH_REGIME_HIGH_VOLATILITY:
         return "HIGH VOLATILITY";

      case KH_REGIME_LOW_VOLATILITY:
         return "LOW VOLATILITY";

      default:
         return "NEUTRAL";
   }
}


//====================================================================
// SYSTEM STATUS
//====================================================================

void GetKHSystemStatus(
   KHSystemStatus &status
)
{
   status.eaRunning =
      g_khayaInitialized;

   status.autoTrading =
      InpAutoTrading;

   status.sessionOpen =
      g_sessionOpen;

   status.weekendClosed =
      g_weekendClosed;

   status.marketConnected =
      KHMarketConnected();

   status.tradingAllowed =
      (
         g_khayaInitialized &&
         g_sessionOpen &&
         !g_weekendClosed &&
         status.marketConnected
      );

   status.symbolsMonitored =
      g_marketWatchCount;

   status.symbolsReady =
      g_readySymbolCount;

   status.bullishSymbols =
      g_bullishSymbols;

   status.bearishSymbols =
      g_bearishSymbols;

   status.serverTime =
      TimeCurrent();
}


//====================================================================
// KHAYA MOBILE API - STATUS ONLY
//====================================================================

input string InpKHApiUrl = "http://127.0.0.1:8000/api/ea/status";

void SendKHStatusToApi(KHSystemStatus &status)
{
   string json =
      "{"
      "\"ea_running\":" + (status.eaRunning ? "true" : "false") + ","
      "\"auto_trading\":" + (status.autoTrading ? "true" : "false") + ","
      "\"session_open\":" + (status.sessionOpen ? "true" : "false") + ","
      "\"market_connected\":" + (status.marketConnected ? "true" : "false") + ","
      "\"symbols_monitored\":" + IntegerToString(status.symbolsMonitored) + ","
      "\"symbols_ready\":" + IntegerToString(status.symbolsReady) + ","
      "\"bullish_symbols\":" + IntegerToString(status.bullishSymbols) + ","
      "\"bearish_symbols\":" + IntegerToString(status.bearishSymbols) + ","
      "\"trading_allowed\":" + (status.tradingAllowed ? "true" : "false") +
      "}";

   char data[];
   char result[];
   string response_headers;

   int data_size = StringToCharArray(
      json,
      data,
      0,
      WHOLE_ARRAY,
      CP_UTF8
   );

   if(data_size > 0)
      ArrayResize(data, data_size - 1);

   string headers = "Content-Type: application/json\r\n";

   ResetLastError();

   int response_code = WebRequest(
      "POST",
      InpKHApiUrl,
      headers,
      5000,
      data,
      result,
      response_headers
   );

   if(response_code == -1)
   {
      Print("KHAYA API FAILED | ERROR=", GetLastError());
      return;
   }

   Print("KHAYA API STATUS SENT | HTTP=", response_code);
   Print("KHAYA API RESPONSE | ", CharArrayToString(result));
}

//====================================================================
// MOBILE / VPS STATUS
//====================================================================

void UpdateKHMobileStatus()
{
   KHSystemStatus status;

   GetKHSystemStatus(
      status
   );


   if(
      TimeCurrent() -
      g_lastStatusTime <
      5
   )
   {
      return;
   }


   g_lastStatusTime =
      TimeCurrent();


   Comment(
      "KHAYA\n",
      "==============================\n",
      "EA: ",
      status.eaRunning ? "RUNNING" : "STOPPED",
      "\n",
      "AUTO: ",
      status.autoTrading ? "ON" : "OFF",
      "\n",
      "SESSION: ",
      status.sessionOpen ? "OPEN" : "CLOSED",
      "\n",
      "VPS/MT5 CONNECTION: ",
      status.marketConnected ? "CONNECTED" : "DISCONNECTED",
      "\n",
      "SYMBOLS: ",
      status.symbolsMonitored,
      "\n",
      "READY: ",
      status.symbolsReady,
      "\n",
      "BULLISH: ",
      status.bullishSymbols,
      "\n",
      "BEARISH: ",
      status.bearishSymbols,
      "\n",
      "TRADING: ",
      status.tradingAllowed ? "READY" : "WAITING",
      "\n",
      "=============================="
   );

   // Send the live status to the KHAYA API every 5 seconds.
   SendKHStatusToApi(status);
}


//====================================================================
// POSITION FOUNDATION
//====================================================================

int KHOpenPositionsCount()
{
   int count = 0;


   int total =
      PositionsTotal();


   for(
      int index = 0;
      index < total;
      index++
   )
   {
      ulong ticket =
         PositionGetTicket(
            index
         );


      if(ticket == 0)
         continue;


      string symbol =
         PositionGetString(
            POSITION_SYMBOL
         );


      long magic =
         PositionGetInteger(
            POSITION_MAGIC
         );


      if(
         magic ==
         (long)InpMagicNumber
      )
      {
         if(symbol != "")
            count++;
      }
   }


   return count;
}


//====================================================================
// SAFE TRADING STATE
//====================================================================

bool KHTradingEnvironmentReady()
{
   if(!g_khayaInitialized)
      return false;


   if(!InpAutoTrading)
      return false;


   if(!g_sessionOpen)
      return false;


   if(g_weekendClosed)
      return false;


   if(!KHMarketConnected())
      return false;


   return true;
}


//====================================================================
// STATUS DISPLAY
//====================================================================

void PrintKHStatus()
{
   KHSystemStatus status;

   GetKHSystemStatus(
      status
   );


   Print(
      "KHAYA STATUS | ",
      "EA=",
      status.eaRunning ? "RUNNING" : "STOPPED",
      " | AUTO=",
      status.autoTrading ? "ON" : "OFF",
      " | SESSION=",
      status.sessionOpen ? "OPEN" : "CLOSED",
      " | SYMBOLS=",
      status.symbolsMonitored,
      " | READY=",
      status.symbolsReady,
      " | BULL=",
      status.bullishSymbols,
      " | BEAR=",
      status.bearishSymbols,
      " | POSITIONS=",
      KHOpenPositionsCount()
   );
}


//+------------------------------------------------------------------+
//|                  KHAYA PHASES 9 - 16                             |
//|        Structure / Liquidity / Momentum / Signal Engine          |
//+------------------------------------------------------------------+


//====================================================================
// PHASE 9 — MARKET STRUCTURE
//====================================================================

struct KHStructureData
{
   double swingHigh;
   double swingLow;

   double previousSwingHigh;
   double previousSwingLow;

   bool higherHigh;
   bool higherLow;

   bool lowerHigh;
   bool lowerLow;

   bool breakOfStructure;
   bool changeOfCharacter;

   KHTFDirection direction;

   int strength;
};


//--------------------------------------------------------------------
// Find highest high
//--------------------------------------------------------------------

double KHFindHighestHigh(
   string symbol,
   ENUM_TIMEFRAMES timeframe,
   int lookback
)
{
   if(lookback < 2)
      return 0.0;


   int shift =
      iHighest(
         symbol,
         timeframe,
         MODE_HIGH,
         lookback,
         1
      );


   if(shift < 0)
      return 0.0;


   return iHigh(
      symbol,
      timeframe,
      shift
   );
}


//--------------------------------------------------------------------
// Find lowest low
//--------------------------------------------------------------------

double KHFindLowestLow(
   string symbol,
   ENUM_TIMEFRAMES timeframe,
   int lookback
)
{
   if(lookback < 2)
      return 0.0;


   int shift =
      iLowest(
         symbol,
         timeframe,
         MODE_LOW,
         lookback,
         1
      );


   if(shift < 0)
      return 0.0;


   return iLow(
      symbol,
      timeframe,
      shift
   );
}


//--------------------------------------------------------------------
// Structure analysis
//--------------------------------------------------------------------

bool AnalyzeKHStructure(
   string symbol,
   ENUM_TIMEFRAMES timeframe,
   KHStructureData &structure
)
{
   structure.swingHigh = 0.0;
   structure.swingLow = 0.0;

   structure.previousSwingHigh = 0.0;
   structure.previousSwingLow = 0.0;

   structure.higherHigh = false;
   structure.higherLow = false;

   structure.lowerHigh = false;
   structure.lowerLow = false;

   structure.breakOfStructure = false;
   structure.changeOfCharacter = false;

   structure.direction =
      KH_TF_NEUTRAL;

   structure.strength = 0;


   int lookback = 30;


   structure.swingHigh =
      KHFindHighestHigh(
         symbol,
         timeframe,
         lookback
      );


   structure.swingLow =
      KHFindLowestLow(
         symbol,
         timeframe,
         lookback
      );


   if(
      structure.swingHigh <= 0 ||
      structure.swingLow <= 0
   )
   {
      return false;
   }


   int secondHighShift =
      iHighest(
         symbol,
         timeframe,
         MODE_HIGH,
         lookback / 2,
         lookback / 2
      );


   int secondLowShift =
      iLowest(
         symbol,
         timeframe,
         MODE_LOW,
         lookback / 2,
         lookback / 2
      );


   if(
      secondHighShift >= 0
   )
   {
      structure.previousSwingHigh =
         iHigh(
            symbol,
            timeframe,
            secondHighShift
         );
   }


   if(
      secondLowShift >= 0
   )
   {
      structure.previousSwingLow =
         iLow(
            symbol,
            timeframe,
            secondLowShift
         );
   }


   if(
      structure.previousSwingHigh > 0
   )
   {
      structure.higherHigh =
         structure.swingHigh >
         structure.previousSwingHigh;

      structure.lowerHigh =
         structure.swingHigh <
         structure.previousSwingHigh;
   }


   if(
      structure.previousSwingLow > 0
   )
   {
      structure.higherLow =
         structure.swingLow >
         structure.previousSwingLow;

      structure.lowerLow =
         structure.swingLow <
         structure.previousSwingLow;
   }


   double closePrice =
      iClose(
         symbol,
         timeframe,
         0
      );


   if(closePrice <= 0)
      return false;


   if(
      structure.higherHigh &&
      structure.higherLow
   )
   {
      structure.direction =
         KH_TF_BULLISH;

      structure.strength = 75;
   }
   else
   if(
      structure.lowerHigh &&
      structure.lowerLow
   )
   {
      structure.direction =
         KH_TF_BEARISH;

      structure.strength = 75;
   }
   else
   if(
      closePrice >
      structure.swingHigh
   )
   {
      structure.breakOfStructure =
         true;

      structure.direction =
         KH_TF_BULLISH;

      structure.strength = 85;
   }
   else
   if(
      closePrice <
      structure.swingLow
   )
   {
      structure.breakOfStructure =
         true;

      structure.direction =
         KH_TF_BEARISH;

      structure.strength = 85;
   }
   else
   {
      structure.direction =
         KH_TF_NEUTRAL;

      structure.strength = 40;
   }


   return true;
}


//====================================================================
// PHASE 10 — LIQUIDITY ENGINE
//====================================================================

struct KHLiquidityData
{
   double buySideLevel;
   double sellSideLevel;

   double equalHighLevel;
   double equalLowLevel;

   bool equalHighs;
   bool equalLows;

   bool buySideSweep;
   bool sellSideSweep;

   bool bullishRejection;
   bool bearishRejection;

   KHTFDirection sweepDirection;

   int qualityScore;
};


//--------------------------------------------------------------------
// Liquidity analysis
//--------------------------------------------------------------------

bool AnalyzeKHLiquidity(
   string symbol,
   ENUM_TIMEFRAMES timeframe,
   KHLiquidityData &liquidity
)
{
   liquidity.buySideLevel = 0.0;
   liquidity.sellSideLevel = 0.0;

   liquidity.equalHighLevel = 0.0;
   liquidity.equalLowLevel = 0.0;

   liquidity.equalHighs = false;
   liquidity.equalLows = false;

   liquidity.buySideSweep = false;
   liquidity.sellSideSweep = false;

   liquidity.bullishRejection = false;
   liquidity.bearishRejection = false;

   liquidity.sweepDirection =
      KH_TF_NEUTRAL;

   liquidity.qualityScore = 0;


   double point =
      SymbolInfoDouble(
         symbol,
         SYMBOL_POINT
      );


   if(point <= 0)
      return false;


   double atr =
      GetKHATRValue(
         symbol,
         timeframe,
         InpATRPeriod,
         0
      );


   if(atr <= 0)
      return false;


   liquidity.buySideLevel =
      KHFindHighestHigh(
         symbol,
         timeframe,
         30
      );


   liquidity.sellSideLevel =
      KHFindLowestLow(
         symbol,
         timeframe,
         30
      );


   if(
      liquidity.buySideLevel <= 0 ||
      liquidity.sellSideLevel <= 0
   )
   {
      return false;
   }


   double previousHigh =
      iHigh(
         symbol,
         timeframe,
         1
      );


   double previousLow =
      iLow(
         symbol,
         timeframe,
         1
      );


   double previousOpen =
      iOpen(
         symbol,
         timeframe,
         1
      );


   double previousClose =
      iClose(
         symbol,
         timeframe,
         1
      );


   double currentHigh =
      iHigh(
         symbol,
         timeframe,
         0
      );


   double currentLow =
      iLow(
         symbol,
         timeframe,
         0
      );


   double currentClose =
      iClose(
         symbol,
         timeframe,
         0
      );


   if(
      previousHigh <= 0 ||
      previousLow <= 0 ||
      currentHigh <= 0 ||
      currentLow <= 0
   )
   {
      return false;
   }


   double tolerance =
      atr * 0.15;


   liquidity.equalHighs =
      MathAbs(
         currentHigh -
         previousHigh
      ) <= tolerance;


   liquidity.equalLows =
      MathAbs(
         currentLow -
         previousLow
      ) <= tolerance;


   liquidity.equalHighLevel =
      MathMax(
         currentHigh,
         previousHigh
      );


   liquidity.equalLowLevel =
      MathMin(
         currentLow,
         previousLow
      );


   liquidity.buySideSweep =
      (
         currentHigh >
         previousHigh &&
         currentClose <
         previousHigh
      );


   liquidity.sellSideSweep =
      (
         currentLow <
         previousLow &&
         currentClose >
         previousLow
      );


   liquidity.bearishRejection =
      (
         currentHigh >
         currentClose &&
         currentHigh -
         currentClose >=
         atr * 0.20
      );


   liquidity.bullishRejection =
      (
         currentClose >
         currentLow &&
         currentClose -
         currentLow >=
         atr * 0.20
      );


   if(liquidity.sellSideSweep)
   {
      liquidity.sweepDirection =
         KH_TF_BULLISH;

      liquidity.qualityScore += 40;
   }


   if(liquidity.buySideSweep)
   {
      liquidity.sweepDirection =
         KH_TF_BEARISH;

      liquidity.qualityScore += 40;
   }


   if(liquidity.equalHighs)
      liquidity.qualityScore += 15;


   if(liquidity.equalLows)
      liquidity.qualityScore += 15;


   if(liquidity.bullishRejection)
      liquidity.qualityScore += 15;


   if(liquidity.bearishRejection)
      liquidity.qualityScore += 15;


   if(liquidity.qualityScore > 100)
      liquidity.qualityScore = 100;


   return true;
}


//====================================================================
// PHASE 11 — MOMENTUM ENGINE
//====================================================================

struct KHMomentumData
{
   double currentClose;

   double previousClose;

   double fastEMA;

   double slowEMA;

   double priceChange;

   double momentumRatio;

   bool bullish;

   bool bearish;

   int bullishScore;

   int bearishScore;

   int qualityScore;
};


//--------------------------------------------------------------------
// Momentum analysis
//--------------------------------------------------------------------

bool AnalyzeKHMomentum(
   string symbol,
   ENUM_TIMEFRAMES timeframe,
   KHMomentumData &momentum
)
{
   momentum.currentClose = 0.0;

   momentum.previousClose = 0.0;

   momentum.fastEMA = 0.0;

   momentum.slowEMA = 0.0;

   momentum.priceChange = 0.0;

   momentum.momentumRatio = 0.0;

   momentum.bullish = false;

   momentum.bearish = false;

   momentum.bullishScore = 0;

   momentum.bearishScore = 0;

   momentum.qualityScore = 0;


   momentum.currentClose =
      iClose(
         symbol,
         timeframe,
         0
      );


   momentum.previousClose =
      iClose(
         symbol,
         timeframe,
         1
      );


   momentum.fastEMA =
      GetKHMovingAverage(
         symbol,
         timeframe,
         InpFastEMA,
         0
      );


   momentum.slowEMA =
      GetKHMovingAverage(
         symbol,
         timeframe,
         InpSlowEMA,
         0
      );


   if(
      momentum.currentClose <= 0 ||
      momentum.previousClose <= 0 ||
      momentum.fastEMA <= 0 ||
      momentum.slowEMA <= 0
   )
   {
      return false;
   }


   momentum.priceChange =
      momentum.currentClose -
      momentum.previousClose;


   double atr =
      GetKHATRValue(
         symbol,
         timeframe,
         InpATRPeriod,
         0
      );


   if(atr > 0)
   {
      momentum.momentumRatio =
         MathAbs(
            momentum.priceChange
         ) /
         atr;
   }


   if(
      momentum.currentClose >
      momentum.fastEMA &&
      momentum.fastEMA >
      momentum.slowEMA &&
      momentum.priceChange > 0
   )
   {
      momentum.bullish = true;

      momentum.bullishScore += 50;
   }


   if(
      momentum.currentClose <
      momentum.fastEMA &&
      momentum.fastEMA <
      momentum.slowEMA &&
      momentum.priceChange < 0
   )
   {
      momentum.bearish = true;

      momentum.bearishScore += 50;
   }


   if(momentum.momentumRatio >= 0.10)
   {
      if(momentum.priceChange > 0)
         momentum.bullishScore += 20;

      if(momentum.priceChange < 0)
         momentum.bearishScore += 20;
   }


   if(momentum.momentumRatio >= 0.25)
   {
      if(momentum.priceChange > 0)
         momentum.bullishScore += 20;

      if(momentum.priceChange < 0)
         momentum.bearishScore += 20;
   }


   momentum.qualityScore =
      MathMax(
         momentum.bullishScore,
         momentum.bearishScore
      );


   if(momentum.qualityScore > 100)
      momentum.qualityScore = 100;


   return true;
}


//====================================================================
// PHASE 12 — SIGNAL ENGINE
//====================================================================

enum KHSignalDirection
{
   KH_SIGNAL_NONE = 0,
   KH_SIGNAL_BUY,
   KH_SIGNAL_SELL
};


struct KHSignalData
{
   KHSignalDirection direction;

   int buyScore;

   int sellScore;

   int confidence;

   bool valid;

   bool strongSignal;

   string reason;
};


//--------------------------------------------------------------------
// Signal direction name
//--------------------------------------------------------------------

string KHSignalToString(
   KHSignalDirection direction
)
{
   if(direction == KH_SIGNAL_BUY)
      return "BUY";

   if(direction == KH_SIGNAL_SELL)
      return "SELL";

   return "NONE";
}


//--------------------------------------------------------------------
// Signal builder
//--------------------------------------------------------------------

bool BuildKHSignal(
   string symbol,
   KHRegimeData &regime,
   KHMultiTFData &mtf,
   KHStructureData &structure,
   KHLiquidityData &liquidity,
   KHMomentumData &momentum,
   KHSignalData &signal
)
{
   signal.direction =
      KH_SIGNAL_NONE;

   signal.buyScore = 0;

   signal.sellScore = 0;

   signal.confidence = 0;

   signal.valid = false;

   signal.strongSignal = false;

   signal.reason = "";


   //===============================================================
   // TREND / REGIME
   //===============================================================

   if(
      regime.regime ==
      KH_REGIME_TREND_UP
   )
   {
      signal.buyScore += 20;
   }


   if(
      regime.regime ==
      KH_REGIME_TREND_DOWN
   )
   {
      signal.sellScore += 20;
   }


   //===============================================================
   // MULTI-TIMEFRAME
   //===============================================================

   if(
      mtf.overallDirection ==
      KH_TF_BULLISH
   )
   {
      signal.buyScore +=
         20 +
         mtf.alignmentScore * 5;
   }


   if(
      mtf.overallDirection ==
      KH_TF_BEARISH
   )
   {
      signal.sellScore +=
         20 +
         mtf.alignmentScore * 5;
   }


   //===============================================================
   // STRUCTURE
   //===============================================================

   if(
      structure.direction ==
      KH_TF_BULLISH
   )
   {
      signal.buyScore +=
         structure.strength / 4;
   }


   if(
      structure.direction ==
      KH_TF_BEARISH
   )
   {
      signal.sellScore +=
         structure.strength / 4;
   }


   if(
      structure.breakOfStructure &&
      structure.direction ==
      KH_TF_BULLISH
   )
   {
      signal.buyScore += 15;
   }


   if(
      structure.breakOfStructure &&
      structure.direction ==
      KH_TF_BEARISH
   )
   {
      signal.sellScore += 15;
   }


   //===============================================================
   // LIQUIDITY
   //===============================================================

   if(
      liquidity.sweepDirection ==
      KH_TF_BULLISH
   )
   {
      signal.buyScore +=
         liquidity.qualityScore / 4;
   }


   if(
      liquidity.sweepDirection ==
      KH_TF_BEARISH
   )
   {
      signal.sellScore +=
         liquidity.qualityScore / 4;
   }


   if(liquidity.bullishRejection)
      signal.buyScore += 10;


   if(liquidity.bearishRejection)
      signal.sellScore += 10;


   //===============================================================
   // MOMENTUM
   //===============================================================

   signal.buyScore +=
      momentum.bullishScore / 4;


   signal.sellScore +=
      momentum.bearishScore / 4;


   //===============================================================
   // FINAL DECISION
   //===============================================================

   if(
      signal.buyScore >= 60 &&
      signal.buyScore >
      signal.sellScore + 10
   )
   {
      signal.direction =
         KH_SIGNAL_BUY;

      signal.confidence =
         signal.buyScore;

      signal.valid = true;

      signal.reason =
         "Bullish trend/structure/momentum alignment";
   }
   else
   if(
      signal.sellScore >= 60 &&
      signal.sellScore >
      signal.buyScore + 10
   )
   {
      signal.direction =
         KH_SIGNAL_SELL;

      signal.confidence =
         signal.sellScore;

      signal.valid = true;

      signal.reason =
         "Bearish trend/structure/momentum alignment";
   }


   if(
      signal.confidence >= 80
   )
   {
      signal.strongSignal = true;
   }


   return signal.valid;
}


//====================================================================
// PHASE 13 — ENTRY VALIDATION
//====================================================================

bool KHEntryAllowed(
   string symbol,
   KHSignalData &signal
)
{
   if(!signal.valid)
      return false;


   if(!KHTradingEnvironmentReady())
      return false;


   KHMarketData data;


   if(
      !GetKHMarketData(
         symbol,
         data
      )
   )
   {
      return false;
   }


   if(
      !KHSpreadAllowed(
         data
      )
   )
   {
      return false;
   }


   if(data.bid <= 0 || data.ask <= 0)
      return false;


   if(
      signal.direction ==
      KH_SIGNAL_BUY &&
      data.ask <= 0
   )
   {
      return false;
   }


   if(
      signal.direction ==
      KH_SIGNAL_SELL &&
      data.bid <= 0
   )
   {
      return false;
   }


   return true;
}


//====================================================================
// PHASE 14 — RISK FOUNDATION
//====================================================================

input double InpRiskPercent = 0.50;

input double InpStopATRMultiplier = 1.50;

input double InpTakeProfitATRMultiplier = 2.00;


//--------------------------------------------------------------------
// Calculate risk volume
//--------------------------------------------------------------------

double KHCalculateVolume(
   string symbol,
   double stopDistance
)
{
   if(stopDistance <= 0)
      return 0.0;


   double balance =
      AccountInfoDouble(
         ACCOUNT_BALANCE
      );


   double riskMoney =
      balance *
      InpRiskPercent /
      100.0;


   double tickSize =
      SymbolInfoDouble(
         symbol,
         SYMBOL_TRADE_TICK_SIZE
      );


   double tickValue =
      SymbolInfoDouble(
         symbol,
         SYMBOL_TRADE_TICK_VALUE
      );


   double volumeMin =
      SymbolInfoDouble(
         symbol,
         SYMBOL_VOLUME_MIN
      );


   double volumeMax =
      SymbolInfoDouble(
         symbol,
         SYMBOL_VOLUME_MAX
      );


   double volumeStep =
      SymbolInfoDouble(
         symbol,
         SYMBOL_VOLUME_STEP
      );


   if(
      tickSize <= 0 ||
      tickValue <= 0 ||
      volumeMin <= 0 ||
      volumeStep <= 0
   )
   {
      return 0.0;
   }


   double moneyPerLot =
      (
         stopDistance /
         tickSize
      ) *
      tickValue;


   if(moneyPerLot <= 0)
      return 0.0;


   double volume =
      riskMoney /
      moneyPerLot;


   volume =
      MathFloor(
         volume /
         volumeStep
      ) *
      volumeStep;


   if(volume < volumeMin)
      volume = volumeMin;


   if(
      volumeMax > 0 &&
      volume > volumeMax
   )
   {
      volume = volumeMax;
   }


   return NormalizeDouble(
      volume,
      2
   );
}


//--------------------------------------------------------------------
// Calculate SL/TP
//--------------------------------------------------------------------

bool KHCalculateStops(
   string symbol,
   KHSignalDirection direction,
   double &stopLoss,
   double &takeProfit
)
{
   double atr =
      GetKHATRValue(
         symbol,
         InpFastTimeframe,
         InpATRPeriod,
         0
      );


   if(atr <= 0)
      return false;


   double point =
      SymbolInfoDouble(
         symbol,
         SYMBOL_POINT
      );


   int digits =
      (int)SymbolInfoInteger(
         symbol,
         SYMBOL_DIGITS
      );


   if(point <= 0)
      return false;


   double bid =
      SymbolInfoDouble(
         symbol,
         SYMBOL_BID
      );


   double ask =
      SymbolInfoDouble(
         symbol,
         SYMBOL_ASK
      );


   double stopDistance =
      atr *
      InpStopATRMultiplier;


   double targetDistance =
      atr *
      InpTakeProfitATRMultiplier;


   if(
      direction ==
      KH_SIGNAL_BUY
   )
   {
      stopLoss =
         ask -
         stopDistance;

      takeProfit =
         ask +
         targetDistance;
   }
   else
   if(
      direction ==
      KH_SIGNAL_SELL
   )
   {
      stopLoss =
         bid +
         stopDistance;

      takeProfit =
         bid -
         targetDistance;
   }
   else
   {
      return false;
   }


   stopLoss =
      NormalizeDouble(
         stopLoss,
         digits
      );


   takeProfit =
      NormalizeDouble(
         takeProfit,
         digits
      );


   return true;
}


//====================================================================
// PHASE 15 — EXECUTION FOUNDATION
//====================================================================

bool KHExecutionPreCheck(
   string symbol,
   KHSignalData &signal
)
{
   if(
      !KHEntryAllowed(
         symbol,
         signal
      )
   )
   {
      return false;
   }


   int existing =
      KHOpenPositionsCount();


   // The actual maximum-position rule will be expanded
   // in the final execution phase.


   if(existing < 0)
      return false;


   return true;
}


//====================================================================
// PHASE 16 — OPEN POSITION MANAGEMENT FOUNDATION
//====================================================================

input bool InpUseBreakeven = true;

input double InpBreakevenATR = 1.00;

input bool InpUseTrailingStop = true;

input double InpTrailingATR = 1.20;


//--------------------------------------------------------------------
// Manage one position
//--------------------------------------------------------------------

void KHManagePosition(
   ulong ticket
)
{
   if(ticket == 0)
      return;


   if(
      !PositionSelectByTicket(
         ticket
      )
   )
   {
      return;
   }


   long magic =
      PositionGetInteger(
         POSITION_MAGIC
      );


   if(
      magic !=
      (long)InpMagicNumber
   )
   {
      return;
   }


   string symbol =
      PositionGetString(
         POSITION_SYMBOL
      );


   if(symbol == "")
      return;


   ENUM_POSITION_TYPE type =
      (ENUM_POSITION_TYPE)
      PositionGetInteger(
         POSITION_TYPE
      );


   double openPrice =
      PositionGetDouble(
         POSITION_PRICE_OPEN
      );


   double currentSL =
      PositionGetDouble(
         POSITION_SL
      );


   double currentTP =
      PositionGetDouble(
         POSITION_TP
      );


   double point =
      SymbolInfoDouble(
         symbol,
         SYMBOL_POINT
      );


   int digits =
      (int)SymbolInfoInteger(
         symbol,
         SYMBOL_DIGITS
      );


   if(point <= 0)
      return;


   double bid =
      SymbolInfoDouble(
         symbol,
         SYMBOL_BID
      );


   double ask =
      SymbolInfoDouble(
         symbol,
         SYMBOL_ASK
      );


   double atr =
      GetKHATRValue(
         symbol,
         InpFastTimeframe,
         InpATRPeriod,
         0
      );


   if(atr <= 0)
      return;


   double newSL =
      currentSL;


   if(
      type ==
      POSITION_TYPE_BUY
   )
   {
      double profitDistance =
         bid -
         openPrice;


      if(
         InpUseBreakeven &&
         profitDistance >=
         atr * InpBreakevenATR
      )
      {
         if(
            currentSL <= 0 ||
            currentSL < openPrice
         )
         {
            newSL =
               NormalizeDouble(
                  openPrice,
                  digits
               );
         }
      }


      if(
         InpUseTrailingStop &&
         profitDistance >=
         atr * InpTrailingATR
      )
      {
         double trailingSL =
            bid -
            atr * InpTrailingATR;


         trailingSL =
            NormalizeDouble(
               trailingSL,
               digits
            );


         if(
            newSL <= 0 ||
            trailingSL > newSL
         )
         {
            newSL = trailingSL;
         }
      }
   }


   if(
      type ==
      POSITION_TYPE_SELL
   )
   {
      double profitDistance =
         openPrice -
         ask;


      if(
         InpUseBreakeven &&
         profitDistance >=
         atr * InpBreakevenATR
      )
      {
         if(
            currentSL <= 0 ||
            currentSL > openPrice
         )
         {
            newSL =
               NormalizeDouble(
                  openPrice,
                  digits
               );
         }
      }


      if(
         InpUseTrailingStop &&
         profitDistance >=
         atr * InpTrailingATR
      )
      {
         double trailingSL =
            ask +
            atr * InpTrailingATR;


         trailingSL =
            NormalizeDouble(
               trailingSL,
               digits
            );


         if(
            newSL <= 0 ||
            trailingSL < newSL
         )
         {
            newSL = trailingSL;
         }
      }
   }


   // Actual position modification is deliberately
   // connected to the final execution layer.
}


//--------------------------------------------------------------------
// Manage all KHAYA positions
//--------------------------------------------------------------------

void KHManageOpenPositions()
{
   int total =
      PositionsTotal();


   for(
      int index = total - 1;
      index >= 0;
      index--
   )
   {
      ulong ticket =
         PositionGetTicket(
            index
         );


      if(ticket == 0)
         continue;


      KHManagePosition(
         ticket
      );
   }
}


//====================================================================
// PHASE 9-16 DIAGNOSTIC ENGINE
//====================================================================

void RunKHAdvancedAnalysis(
   string symbol
)
{
   KHMarketData marketData;


   if(
      !GetKHMarketData(
         symbol,
         marketData
      )
   )
   {
      return;
   }


   if(
      !KHSpreadAllowed(
         marketData
      )
   )
   {
      return;
   }


   KHRegimeData regime;


   if(
      !AnalyzeKHMarketRegime(
         symbol,
         regime
      )
   )
   {
      return;
   }


   KHMultiTFData mtf;


   if(
      !AnalyzeKHMultiTimeframe(
         symbol,
         mtf
      )
   )
   {
      return;
   }


   KHStructureData structure;


   if(
      !AnalyzeKHStructure(
         symbol,
         InpConfirmTimeframe,
         structure
      )
   )
   {
      return;
   }


   KHLiquidityData liquidity;


   if(
      !AnalyzeKHLiquidity(
         symbol,
         InpFastTimeframe,
         liquidity
      )
   )
   {
      return;
   }


   KHMomentumData momentum;


   if(
      !AnalyzeKHMomentum(
         symbol,
         InpFastTimeframe,
         momentum
      )
   )
   {
      return;
   }


   KHSignalData signal;


   bool signalFound =
      BuildKHSignal(
         symbol,
         regime,
         mtf,
         structure,
         liquidity,
         momentum,
         signal
      );


   if(signalFound)
   {
      Print(
         "KHAYA SIGNAL | ",
         symbol,
         " | ",
         KHSignalToString(
            signal.direction
         ),
         " | BUY=",
         signal.buyScore,
         " | SELL=",
         signal.sellScore,
         " | CONF=",
         signal.confidence,
         " | STRONG=",
         signal.strongSignal ? "YES" : "NO"
      );
   }
}


//====================================================================
// ADVANCED ANALYSIS LOOP
//====================================================================

void RunKHAdvancedMarketAnalysis()
{
   if(!g_khayaInitialized)
      return;


   int totalSymbols =
      SymbolsTotal(true);


   for(
      int index = 0;
      index < totalSymbols;
      index++
   )
   {
      string symbol =
         SymbolName(
            index,
            true
         );


      if(symbol == "")
         continue;


      RunKHAdvancedAnalysis(
         symbol
      );
   }


   KHManageOpenPositions();
}



//+------------------------------------------------------------------+
//|                         KHAYA.mq5                                 |
//|                    PHASES 17 - 25                                |
//|              Execution / Protection / Trade Engine               |
//+------------------------------------------------------------------+

//====================================================================
// PHASE 17 — TRADE EXECUTION ENGINE
//====================================================================

#include <Trade/Trade.mqh>

CTrade g_khayaTrade;


//====================================================================
// EXECUTION INPUTS
//====================================================================

input int InpMaxOpenPositions = 3;

input bool InpOnePositionPerSymbol = true;

input bool InpAllowBuyTrades = true;

input bool InpAllowSellTrades = true;

input int InpMaxSlippagePoints = 20;

input int InpMinimumSignalConfidence = 60;

input int InpStrongSignalConfidence = 80;

input bool InpTradeOnlyStrongSignals = false;

input int InpCooldownSeconds = 2;

input bool InpUseEmergencyStop = true;

input double InpEmergencyATRMultiplier = 3.00;


//====================================================================
// EXECUTION STATE
//====================================================================

datetime g_lastTradeTime = 0;

datetime g_lastEntryBarTime = 0;

string g_lastTradeSymbol = "";

int g_totalBuyTrades = 0;

int g_totalSellTrades = 0;

int g_totalTradeAttempts = 0;

int g_successfulTrades = 0;

int g_failedTrades = 0;


//====================================================================
// TRADE RESULT DESCRIPTION
//====================================================================

string KHTradeRetcodeToString(
   uint retcode
)
{
   switch(retcode)
   {
      case TRADE_RETCODE_DONE:
         return "DONE";

      case TRADE_RETCODE_DONE_PARTIAL:
         return "DONE PARTIAL";

      case TRADE_RETCODE_PLACED:
         return "PLACED";

      case TRADE_RETCODE_REQUOTE:
         return "REQUOTE";

      case TRADE_RETCODE_REJECT:
         return "REJECTED";

      case TRADE_RETCODE_CANCEL:
         return "CANCELLED";

      case TRADE_RETCODE_INVALID:
         return "INVALID";

      case TRADE_RETCODE_INVALID_VOLUME:
         return "INVALID VOLUME";

      case TRADE_RETCODE_INVALID_PRICE:
         return "INVALID PRICE";

      case TRADE_RETCODE_INVALID_STOPS:
         return "INVALID STOPS";

      case TRADE_RETCODE_TRADE_DISABLED:
         return "TRADING DISABLED";

      case TRADE_RETCODE_MARKET_CLOSED:
         return "MARKET CLOSED";

      case TRADE_RETCODE_NO_MONEY:
         return "NOT ENOUGH MONEY";

      case TRADE_RETCODE_PRICE_CHANGED:
         return "PRICE CHANGED";

      case TRADE_RETCODE_PRICE_OFF:
         return "PRICE OFF";

      case TRADE_RETCODE_CONNECTION:
         return "NO CONNECTION";

      case TRADE_RETCODE_TOO_MANY_REQUESTS:
         return "TOO MANY REQUESTS";

      default:
         return "UNKNOWN";
   }
}


//====================================================================
// PHASE 18 — POSITION COUNTING
//====================================================================

int KHCountPositionsBySymbol(
   string symbol
)
{
   int count = 0;

   int total =
      PositionsTotal();

   for(
      int index = 0;
      index < total;
      index++
   )
   {
      ulong ticket =
         PositionGetTicket(
            index
         );

      if(ticket == 0)
         continue;

      if(
         !PositionSelectByTicket(
            ticket
         )
      )
      {
         continue;
      }

      string positionSymbol =
         PositionGetString(
            POSITION_SYMBOL
         );

      long magic =
         PositionGetInteger(
            POSITION_MAGIC
         );

      if(
         magic ==
         (long)InpMagicNumber &&
         positionSymbol ==
         symbol
      )
      {
         count++;
      }
   }

   return count;
}


//====================================================================
// TOTAL KHAYA POSITIONS
//====================================================================

int KHCountAllPositions()
{
   return KHOpenPositionsCount();
}


//====================================================================
// DUPLICATE ENTRY PROTECTION
//====================================================================

bool KHHasPositionOnSymbol(
   string symbol
)
{
   return(
      KHCountPositionsBySymbol(
         symbol
      ) > 0
   );
}


//====================================================================
// TRADE COOLDOWN
//====================================================================

bool KHTradeCooldownPassed()
{
   if(g_lastTradeTime <= 0)
      return true;

   datetime now =
      TimeCurrent();

   return(
      now - g_lastTradeTime >=
      InpCooldownSeconds
   );
}


//====================================================================
// POSITION LIMIT
//====================================================================

bool KHPositionLimitAllowed()
{
   if(
      InpMaxOpenPositions <= 0
   )
   {
      return true;
   }

   return(
      KHCountAllPositions() <
      InpMaxOpenPositions
   );
}


//====================================================================
// VOLUME NORMALIZATION
//====================================================================

double KHNormalizeVolume(
   string symbol,
   double volume
)
{
   double minimum =
      SymbolInfoDouble(
         symbol,
         SYMBOL_VOLUME_MIN
      );

   double maximum =
      SymbolInfoDouble(
         symbol,
         SYMBOL_VOLUME_MAX
      );

   double step =
      SymbolInfoDouble(
         symbol,
         SYMBOL_VOLUME_STEP
      );

   if(
      minimum <= 0 ||
      maximum <= 0 ||
      step <= 0
   )
   {
      return 0.0;
   }

   if(volume < minimum)
      volume = minimum;

   if(volume > maximum)
      volume = maximum;

   volume =
      MathFloor(
         volume / step
      ) * step;

   if(volume < minimum)
      volume = minimum;

   int volumeDigits = 2;

   if(step < 1.0)
      volumeDigits = 2;

   if(step < 0.1)
      volumeDigits = 3;

   if(step < 0.01)
      volumeDigits = 4;

   return(
      NormalizeDouble(
         volume,
         volumeDigits
      )
   );
}


//====================================================================
// BROKER STOP DISTANCE
//====================================================================

double KHMinimumStopDistance(
   string symbol
)
{
   double point =
      SymbolInfoDouble(
         symbol,
         SYMBOL_POINT
      );

   if(point <= 0)
      return 0.0;

   long stopsLevel =
      SymbolInfoInteger(
         symbol,
         SYMBOL_TRADE_STOPS_LEVEL
      );

   long freezeLevel =
      SymbolInfoInteger(
         symbol,
         SYMBOL_TRADE_FREEZE_LEVEL
      );

   long requiredPoints =
      MathMax(
         stopsLevel,
         freezeLevel
      );

   return(
      (double)requiredPoints *
      point
   );
}


//====================================================================
// VALIDATE STOPS
//====================================================================

bool KHValidateStops(
   string symbol,
   KHSignalDirection direction,
   double stopLoss,
   double takeProfit
)
{
   double point =
      SymbolInfoDouble(
         symbol,
         SYMBOL_POINT
      );

   if(point <= 0)
      return false;

   double bid =
      SymbolInfoDouble(
         symbol,
         SYMBOL_BID
      );

   double ask =
      SymbolInfoDouble(
         symbol,
         SYMBOL_ASK
      );

   if(
      bid <= 0 ||
      ask <= 0
   )
   {
      return false;
   }

   double minimumDistance =
      KHMinimumStopDistance(
         symbol
      );

   if(
      direction ==
      KH_SIGNAL_BUY
   )
   {
      if(
         stopLoss <= 0 ||
         takeProfit <= 0
      )
      {
         return false;
      }

      if(
         stopLoss >= ask ||
         takeProfit <= ask
      )
      {
         return false;
      }

      if(
         ask - stopLoss <
         minimumDistance
      )
      {
         return false;
      }

      if(
         takeProfit - ask <
         minimumDistance
      )
      {
         return false;
      }

      return true;
   }

   if(
      direction ==
      KH_SIGNAL_SELL
   )
   {
      if(
         stopLoss <= 0 ||
         takeProfit <= 0
      )
      {
         return false;
      }

      if(
         stopLoss <= bid ||
         takeProfit >= bid
      )
      {
         return false;
      }

      if(
         stopLoss - bid <
         minimumDistance
      )
      {
         return false;
      }

      if(
         bid - takeProfit <
         minimumDistance
      )
      {
         return false;
      }

      return true;
   }

   return false;
}


//====================================================================
// PHASE 19 — BUY EXECUTION
//====================================================================

bool ExecuteKHBuy(
   string symbol,
   KHSignalData &signal
)
{
   if(
      signal.direction !=
      KH_SIGNAL_BUY
   )
   {
      return false;
   }

   if(!InpAllowBuyTrades)
      return false;

   if(!KHTradingEnvironmentReady())
      return false;

   if(
      signal.confidence <
      InpMinimumSignalConfidence
   )
   {
      return false;
   }

   if(
      InpTradeOnlyStrongSignals &&
      !signal.strongSignal
   )
   {
      return false;
   }

   if(
      !KHPositionLimitAllowed()
   )
   {
      return false;
   }

   if(
      InpOnePositionPerSymbol &&
      KHHasPositionOnSymbol(
         symbol
      )
   )
   {
      return false;
   }

   if(
      !KHTradeCooldownPassed()
   )
   {
      return false;
   }

   KHMarketData marketData;

   if(
      !GetKHMarketData(
         symbol,
         marketData
      )
   )
   {
      return false;
   }

   if(
      !KHSpreadAllowed(
         marketData
      )
   )
   {
      return false;
   }

   double stopLoss = 0.0;

   double takeProfit = 0.0;

   if(
      !KHCalculateStops(
         symbol,
         KH_SIGNAL_BUY,
         stopLoss,
         takeProfit
      )
   )
   {
      return false;
   }

   if(
      !KHValidateStops(
         symbol,
         KH_SIGNAL_BUY,
         stopLoss,
         takeProfit
      )
   )
   {
      return false;
   }

   double ask =
      SymbolInfoDouble(
         symbol,
         SYMBOL_ASK
      );

   double stopDistance =
      ask - stopLoss;

   if(stopDistance <= 0)
      return false;

   double volume =
      KHCalculateVolume(
         symbol,
         stopDistance
      );

   volume =
      KHNormalizeVolume(
         symbol,
         volume
      );

   if(volume <= 0)
      return false;

   g_totalTradeAttempts++;

   g_khayaTrade.SetExpertMagicNumber(
      InpMagicNumber
   );

   g_khayaTrade.SetDeviationInPoints(
      InpMaxSlippagePoints
   );

   bool result =
      g_khayaTrade.Buy(
         volume,
         symbol,
         0.0,
         stopLoss,
         takeProfit,
         "KHAYA BUY"
      );

   if(result)
   {
      g_lastTradeTime =
         TimeCurrent();

      g_lastTradeSymbol =
         symbol;

      g_totalBuyTrades++;

      g_successfulTrades++;

      Print(
         "KHAYA EXECUTION | BUY | ",
         symbol,
         " | VOLUME=",
         volume,
         " | SL=",
         stopLoss,
         " | TP=",
         takeProfit,
         " | CONF=",
         signal.confidence
      );

      return true;
   }

   g_failedTrades++;

   Print(
      "KHAYA BUY FAILED | ",
      symbol,
      " | RETCODE=",
      g_khayaTrade.ResultRetcode(),
      " | ",
      KHTradeRetcodeToString(
         g_khayaTrade.ResultRetcode()
      ),
      " | ",
      g_khayaTrade.ResultRetcodeDescription()
   );

   return false;
}


//====================================================================
// PHASE 20 — SELL EXECUTION
//====================================================================

bool ExecuteKHSell(
   string symbol,
   KHSignalData &signal
)
{
   if(
      signal.direction !=
      KH_SIGNAL_SELL
   )
   {
      return false;
   }

   if(!InpAllowSellTrades)
      return false;

   if(!KHTradingEnvironmentReady())
      return false;

   if(
      signal.confidence <
      InpMinimumSignalConfidence
   )
   {
      return false;
   }

   if(
      InpTradeOnlyStrongSignals &&
      !signal.strongSignal
   )
   {
      return false;
   }

   if(
      !KHPositionLimitAllowed()
   )
   {
      return false;
   }

   if(
      InpOnePositionPerSymbol &&
      KHHasPositionOnSymbol(
         symbol
      )
   )
   {
      return false;
   }

   if(
      !KHTradeCooldownPassed()
   )
   {
      return false;
   }

   KHMarketData marketData;

   if(
      !GetKHMarketData(
         symbol,
         marketData
      )
   )
   {
      return false;
   }

   if(
      !KHSpreadAllowed(
         marketData
      )
   )
   {
      return false;
   }

   double stopLoss = 0.0;

   double takeProfit = 0.0;

   if(
      !KHCalculateStops(
         symbol,
         KH_SIGNAL_SELL,
         stopLoss,
         takeProfit
      )
   )
   {
      return false;
   }

   if(
      !KHValidateStops(
         symbol,
         KH_SIGNAL_SELL,
         stopLoss,
         takeProfit
      )
   )
   {
      return false;
   }

   double bid =
      SymbolInfoDouble(
         symbol,
         SYMBOL_BID
      );

   double stopDistance =
      stopLoss - bid;

   if(stopDistance <= 0)
      return false;

   double volume =
      KHCalculateVolume(
         symbol,
         stopDistance
      );

   volume =
      KHNormalizeVolume(
         symbol,
         volume
      );

   if(volume <= 0)
      return false;

   g_totalTradeAttempts++;

   g_khayaTrade.SetExpertMagicNumber(
      InpMagicNumber
   );

   g_khayaTrade.SetDeviationInPoints(
      InpMaxSlippagePoints
   );

   bool result =
      g_khayaTrade.Sell(
         volume,
         symbol,
         0.0,
         stopLoss,
         takeProfit,
         "KHAYA SELL"
      );

   if(result)
   {
      g_lastTradeTime =
         TimeCurrent();

      g_lastTradeSymbol =
         symbol;

      g_totalSellTrades++;

      g_successfulTrades++;

      Print(
         "KHAYA EXECUTION | SELL | ",
         symbol,
         " | VOLUME=",
         volume,
         " | SL=",
         stopLoss,
         " | TP=",
         takeProfit,
         " | CONF=",
         signal.confidence
      );

      return true;
   }

   g_failedTrades++;

   Print(
      "KHAYA SELL FAILED | ",
      symbol,
      " | RETCODE=",
      g_khayaTrade.ResultRetcode(),
      " | ",
      KHTradeRetcodeToString(
         g_khayaTrade.ResultRetcode()
      ),
      " | ",
      g_khayaTrade.ResultRetcodeDescription()
   );

   return false;
}


//====================================================================
// PHASE 21 — COMPLETE SIGNAL PROCESSOR
//====================================================================

bool KHProcessSignal(
   string symbol,
   KHSignalData &signal
)
{
   if(!signal.valid)
      return false;

   if(
      signal.confidence <
      InpMinimumSignalConfidence
   )
   {
      return false;
   }

   if(
      InpTradeOnlyStrongSignals &&
      !signal.strongSignal
   )
   {
      return false;
   }

   if(
      !KHEntryAllowed(
         symbol,
         signal
      )
   )
   {
      return false;
   }

   if(
      signal.direction ==
      KH_SIGNAL_BUY
   )
   {
      return ExecuteKHBuy(
         symbol,
         signal
      );
   }

   if(
      signal.direction ==
      KH_SIGNAL_SELL
   )
   {
      return ExecuteKHSell(
         symbol,
         signal
      );
   }

   return false;
}


//====================================================================
// PHASE 22 — ADVANCED SIGNAL GENERATION
//====================================================================

bool KHBuildLiveSignal(
   string symbol,
   KHSignalData &signal
)
{
   KHMarketData marketData;

   if(
      !GetKHMarketData(
         symbol,
         marketData
      )
   )
   {
      return false;
   }

   if(
      !KHSpreadAllowed(
         marketData
      )
   )
   {
      return false;
   }

   KHRegimeData regime;

   if(
      !AnalyzeKHMarketRegime(
         symbol,
         regime
      )
   )
   {
      return false;
   }

   KHMultiTFData mtf;

   if(
      !AnalyzeKHMultiTimeframe(
         symbol,
         mtf
      )
   )
   {
      return false;
   }

   KHStructureData structure;

   if(
      !AnalyzeKHStructure(
         symbol,
         InpConfirmTimeframe,
         structure
      )
   )
   {
      return false;
   }

   KHLiquidityData liquidity;

   if(
      !AnalyzeKHLiquidity(
         symbol,
         InpFastTimeframe,
         liquidity
      )
   )
   {
      return false;
   }

   KHMomentumData momentum;

   if(
      !AnalyzeKHMomentum(
         symbol,
         InpFastTimeframe,
         momentum
      )
   )
   {
      return false;
   }

   return(
      BuildKHSignal(
         symbol,
         regime,
         mtf,
         structure,
         liquidity,
         momentum,
         signal
      )
   );
}


//====================================================================
// PHASE 23 — FAST TRADING LOOP
//====================================================================

void RunKHExecutionEngine()
{
   if(!g_khayaInitialized)
      return;

   if(!InpAutoTrading)
      return;

   if(!g_sessionOpen)
      return;

   if(g_weekendClosed)
      return;

   if(
      !KHMarketConnected()
   )
   {
      return;
   }

   if(
      !KHPositionLimitAllowed()
   )
   {
      return;
   }

   int totalSymbols =
      SymbolsTotal(true);

   for(
      int index = 0;
      index < totalSymbols;
      index++
   )
   {
      if(
         !KHPositionLimitAllowed()
      )
      {
         break;
      }

      string symbol =
         SymbolName(
            index,
            true
         );

      if(symbol == "")
         continue;

      MqlTick tick;

      if(
         !SymbolInfoTick(
            symbol,
            tick
         )
      )
      {
         continue;
      }

      if(
         tick.bid <= 0 ||
         tick.ask <= 0
      )
      {
         continue;
      }

      if(
         InpOnePositionPerSymbol &&
         KHHasPositionOnSymbol(
            symbol
         )
      )
      {
         continue;
      }

      KHSignalData signal;

      if(
         !KHBuildLiveSignal(
            symbol,
            signal
         )
      )
      {
         continue;
      }

      if(!signal.valid)
         continue;

      KHProcessSignal(
         symbol,
         signal
      );
   }
}


//====================================================================
// PHASE 24 — POSITION MANAGEMENT
//====================================================================

void KHModifyPositionSLTP(
   ulong ticket,
   string symbol,
   double newSL,
   double currentTP
)
{
   if(ticket == 0)
      return;

   if(
      !PositionSelectByTicket(
         ticket
      )
   )
   {
      return;
   }

   g_khayaTrade.SetExpertMagicNumber(
      InpMagicNumber
   );

   if(
      !g_khayaTrade.PositionModify(
         ticket,
         newSL,
         currentTP
      )
   )
   {
      Print(
         "KHAYA POSITION MODIFY FAILED | ",
         symbol,
         " | TICKET=",
         ticket,
         " | RETCODE=",
         g_khayaTrade.ResultRetcode(),
         " | ",
         g_khayaTrade.ResultRetcodeDescription()
      );
   }
}


//====================================================================
// SAFE POSITION MANAGEMENT
//====================================================================

void KHRunPositionManagement()
{
   int total =
      PositionsTotal();

   for(
      int index = total - 1;
      index >= 0;
      index--
   )
   {
      ulong ticket =
         PositionGetTicket(
            index
         );

      if(ticket == 0)
         continue;

      if(
         !PositionSelectByTicket(
            ticket
         )
      )
      {
         continue;
      }

      long magic =
         PositionGetInteger(
            POSITION_MAGIC
         );

      if(
         magic !=
         (long)InpMagicNumber
      )
      {
         continue;
      }

      string symbol =
         PositionGetString(
            POSITION_SYMBOL
         );

      ENUM_POSITION_TYPE type =
         (ENUM_POSITION_TYPE)
         PositionGetInteger(
            POSITION_TYPE
         );

      double openPrice =
         PositionGetDouble(
            POSITION_PRICE_OPEN
         );

      double currentSL =
         PositionGetDouble(
            POSITION_SL
         );

      double currentTP =
         PositionGetDouble(
            POSITION_TP
         );

      double bid =
         SymbolInfoDouble(
            symbol,
            SYMBOL_BID
         );

      double ask =
         SymbolInfoDouble(
            symbol,
            SYMBOL_ASK
         );

      double atr =
         GetKHATRValue(
            symbol,
            InpFastTimeframe,
            InpATRPeriod,
            0
         );

      if(
         atr <= 0 ||
         bid <= 0 ||
         ask <= 0
      )
      {
         continue;
      }

      int digits =
         (int)SymbolInfoInteger(
            symbol,
            SYMBOL_DIGITS
         );

      double newSL =
         currentSL;

      bool modify = false;

      if(
         type ==
         POSITION_TYPE_BUY
      )
      {
         double profitDistance =
            bid - openPrice;

         if(
            InpUseBreakeven &&
            profitDistance >=
            atr * InpBreakevenATR
         )
         {
            double breakeven =
               NormalizeDouble(
                  openPrice,
                  digits
               );

            if(
               currentSL <= 0 ||
               breakeven > currentSL
            )
            {
               newSL = breakeven;

               modify = true;
            }
         }

         if(
            InpUseTrailingStop &&
            profitDistance >=
            atr * InpTrailingATR
         )
         {
            double trailing =
               bid -
               atr * InpTrailingATR;

            trailing =
               NormalizeDouble(
                  trailing,
                  digits
               );

            if(
               newSL <= 0 ||
               trailing > newSL
            )
            {
               newSL = trailing;

               modify = true;
            }
         }

         if(
            modify &&
            newSL < bid
         )
         {
            KHModifyPositionSLTP(
               ticket,
               symbol,
               newSL,
               currentTP
            );
         }
      }


      if(
         type ==
         POSITION_TYPE_SELL
      )
      {
         double profitDistance =
            openPrice - ask;

         if(
            InpUseBreakeven &&
            profitDistance >=
            atr * InpBreakevenATR
         )
         {
            double breakeven =
               NormalizeDouble(
                  openPrice,
                  digits
               );

            if(
               currentSL <= 0 ||
               breakeven < currentSL
            )
            {
               newSL = breakeven;

               modify = true;
            }
         }

         if(
            InpUseTrailingStop &&
            profitDistance >=
            atr * InpTrailingATR
         )
         {
            double trailing =
               ask +
               atr * InpTrailingATR;

            trailing =
               NormalizeDouble(
                  trailing,
                  digits
               );

            if(
               newSL <= 0 ||
               trailing < newSL
            )
            {
               newSL = trailing;

               modify = true;
            }
         }

         if(
            modify &&
            newSL > ask
         )
         {
            KHModifyPositionSLTP(
               ticket,
               symbol,
               newSL,
               currentTP
            );
         }
      }
   }
}


//====================================================================
// PHASE 25 — EMERGENCY PROTECTION
//====================================================================

void KHRunEmergencyProtection()
{
   if(!InpUseEmergencyStop)
      return;

   int total =
      PositionsTotal();

   for(
      int index = total - 1;
      index >= 0;
      index--
   )
   {
      ulong ticket =
         PositionGetTicket(
            index
         );

      if(ticket == 0)
         continue;

      if(
         !PositionSelectByTicket(
            ticket
         )
      )
      {
         continue;
      }

      long magic =
         PositionGetInteger(
            POSITION_MAGIC
         );

      if(
         magic !=
         (long)InpMagicNumber
      )
      {
         continue;
      }

      string symbol =
         PositionGetString(
            POSITION_SYMBOL
         );

      ENUM_POSITION_TYPE type =
         (ENUM_POSITION_TYPE)
         PositionGetInteger(
            POSITION_TYPE
         );

      double openPrice =
         PositionGetDouble(
            POSITION_PRICE_OPEN
         );

      double bid =
         SymbolInfoDouble(
            symbol,
            SYMBOL_BID
         );

      double ask =
         SymbolInfoDouble(
            symbol,
            SYMBOL_ASK
         );

      double atr =
         GetKHATRValue(
            symbol,
            InpFastTimeframe,
            InpATRPeriod,
            0
         );

      if(
         atr <= 0 ||
         bid <= 0 ||
         ask <= 0
      )
      {
         continue;
      }

      double emergencyDistance =
         atr *
         InpEmergencyATRMultiplier;

      bool emergencyClose = false;

      if(
         type ==
         POSITION_TYPE_BUY
      )
      {
         if(
            openPrice - bid >=
            emergencyDistance
         )
         {
            emergencyClose = true;
         }
      }

      if(
         type ==
         POSITION_TYPE_SELL
      )
      {
         if(
            ask - openPrice >=
            emergencyDistance
         )
         {
            emergencyClose = true;
         }
      }

      if(emergencyClose)
      {
         g_khayaTrade.SetExpertMagicNumber(
            InpMagicNumber
         );

         bool result =
            g_khayaTrade.PositionClose(
               ticket
            );

         if(result)
         {
            Print(
               "KHAYA EMERGENCY CLOSE | ",
               symbol,
               " | TICKET=",
               ticket
            );
         }
         else
         {
            Print(
               "KHAYA EMERGENCY CLOSE FAILED | ",
               symbol,
               " | TICKET=",
               ticket,
               " | ",
               g_khayaTrade.ResultRetcodeDescription()
            );
         }
      }
   }
}


//====================================================================
// EXECUTION STATISTICS
//====================================================================

void PrintKHExecutionStatus()
{
   Print(
      "KHAYA EXECUTION STATUS | ",
      "POSITIONS=",
      KHCountAllPositions(),
      " | BUY TRADES=",
      g_totalBuyTrades,
      " | SELL TRADES=",
      g_totalSellTrades,
      " | ATTEMPTS=",
      g_totalTradeAttempts,
      " | SUCCESS=",
      g_successfulTrades,
      " | FAILED=",
      g_failedTrades,
      " | LAST SYMBOL=",
      g_lastTradeSymbol
   );
}


//====================================================================
// MASTER TRADING ENGINE
//====================================================================

void RunKHMasterTradingEngine()
{
   if(!g_khayaInitialized)
      return;

   UpdateKHSession();

   KHRunEmergencyProtection();

   KHRunPositionManagement();

   RunKHExecutionEngine();
}


 
//+------------------------------------------------------------------+
//| PHASE 26A — FINAL EXECUTION CONTROLS                             |
//+------------------------------------------------------------------+

//====================================================================
// EXECUTION SETTINGS
//====================================================================

input int InpMaxOpenPositionsKH = 3;

input int InpMaxPositionsPerSymbolKH = 1;

input int InpEntryCooldownKH = 10;

input int InpMinimumConfidenceKH = 60;

input bool InpAllowBuyKH = true;

input bool InpAllowSellKH = true;


//====================================================================
// EXECUTION STATE
//====================================================================

datetime g_lastKHEntryTime = 0;


//====================================================================
// COUNT POSITIONS FOR SYMBOL
//====================================================================

int KHCountPositionsForSymbol(
   string symbol
)
{
   int count = 0;

   int total =
      PositionsTotal();

   for(
      int index = 0;
      index < total;
      index++
   )
   {
      ulong ticket =
         PositionGetTicket(
            index
         );

      if(ticket == 0)
         continue;

      if(
         !PositionSelectByTicket(
            ticket
         )
      )
      {
         continue;
      }

      long magic =
         PositionGetInteger(
            POSITION_MAGIC
         );

      if(
         magic !=
         (long)InpMagicNumber
      )
      {
         continue;
      }

      string positionSymbol =
         PositionGetString(
            POSITION_SYMBOL
         );

      if(
         positionSymbol ==
         symbol
      )
      {
         count++;
      }
   }

   return count;
}


//====================================================================
// COOLDOWN CHECK
//====================================================================

bool KHExecutionCooldownReady()
{
   if(
      InpEntryCooldownKH <= 0
   )
   {
      return true;
   }

   if(
      g_lastKHEntryTime <= 0
   )
   {
      return true;
   }

   return(
      TimeCurrent() -
      g_lastKHEntryTime >=
      InpEntryCooldownKH
   );
}


//====================================================================
// DIRECTION CHECK
//====================================================================

bool KHExecutionDirectionAllowed(
   KHSignalDirection direction
)
{
   if(
      direction ==
      KH_SIGNAL_BUY
   )
   {
      return InpAllowBuyKH;
   }

   if(
      direction ==
      KH_SIGNAL_SELL
   )
   {
      return InpAllowSellKH;
   }

   return false;
}


//====================================================================
// FINAL EXECUTION PERMISSION
//====================================================================

bool KHExecutionPermission(
   string symbol,
   KHSignalData &signal
)
{
   if(
      !signal.valid
   )
   {
      return false;
   }

   if(
      signal.confidence <
      InpMinimumConfidenceKH
   )
   {
      return false;
   }

   if(
      !KHExecutionDirectionAllowed(
         signal.direction
      )
   )
   {
      return false;
   }

   if(
      !KHTradingEnvironmentReady()
   )
   {
      return false;
   }

   if(
      !KHExecutionCooldownReady()
   )
   {
      return false;
   }

   if(
      KHOpenPositionsCount() >=
      InpMaxOpenPositionsKH
   )
   {
      return false;
   }

   if(
      KHCountPositionsForSymbol(
         symbol
      ) >=
      InpMaxPositionsPerSymbolKH
   )
   {
      return false;
   }

   if(
      !KHEntryAllowed(
         symbol,
         signal
      )
   )
   {
      return false;
   }

   return true;
}


//====================================================================
// EXECUTION STATUS
//====================================================================

void PrintKHExecutionControls()
{
   Print(
      "KHAYA EXECUTION CONTROLS | ",
      "MAX POSITIONS=",
      InpMaxOpenPositionsKH,
      " | MAX/SYMBOL=",
      InpMaxPositionsPerSymbolKH,
      " | COOLDOWN=",
      InpEntryCooldownKH,
      " | MIN CONF=",
      InpMinimumConfidenceKH,
      " | BUY=",
      InpAllowBuyKH ? "ON" : "OFF",
      " | SELL=",
      InpAllowSellKH ? "ON" : "OFF"
   );
}

