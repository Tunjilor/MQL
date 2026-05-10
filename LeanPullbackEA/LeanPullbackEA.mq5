//+------------------------------------------------------------------+
//|  LeanPullbackEA.mq5                                               |
//|  Lean Trend-Following Pullback EA for MT5                         |
//|  VERSION 1.2 — All inputs in main file for Strategy Tester       |
//+------------------------------------------------------------------+
#property copyright "LeanPullbackEA"
#property version   "1.02"
#property strict

//+------------------------------------------------------------------+
//|  ALL INPUTS MUST BE HERE IN THE MAIN FILE                        |
//|  MT5 Strategy Tester only reads inputs from the .mq5 file        |
//+------------------------------------------------------------------+

//--- Core Strategy
input double InpRiskPercent                 = 0.75;
input double InpRewardRiskRatio             = 1.3;
input double InpStopBufferPips              = 7.0;
input double InpMinStopPips                 = 10.0;
input double InpMaxStopPips                 = 35.0;
input double InpMinDistanceFromH1EMA200Pips = 5.0;
input int    InpPullbackLookbackBars        = 5;
input int    InpBodyAvgLookback             = 10;
input double InpMinBodyMultiplier           = 0.7;

//--- Sessions
input int    InpBrokerUtcOffsetHours        = 3;
input int    InpLondonStartHour             = 7;
input int    InpLondonStartMinute           = 30;
input int    InpLondonEndHour               = 11;
input int    InpLondonEndMinute             = 30;
input int    InpNewYorkStartHour            = 13;
input int    InpNewYorkStartMinute          = 30;
input int    InpNewYorkEndHour              = 16;
input int    InpNewYorkEndMinute            = 30;
input int    InpFridayCutoffHour            = 16;
input int    InpFridayCutoffMinute          = 30;

//--- Daily Limits
input int    InpMaxTradesPerSymbolPerDay    = 2;
input int    InpMaxTradesTotalPerDay        = 3;
input double InpMaxDailyLossPercent         = 2.0;

//--- Spread Filters
input double InpMaxSpreadEurUsd             = 3.0;
input double InpMaxSpreadGbpUsd             = 3.5;
input double InpMaxSpreadUsdJpy             = 3.0;
input double InpMaxSpreadAudUsd             = 3.0;

//--- ATR Filters
input int    InpAtrPeriod                   = 14;
input double InpAtrMinEurUsd                = 8.0;
input double InpAtrMaxEurUsd                = 25.0;
input double InpAtrMinGbpUsd                = 10.0;
input double InpAtrMaxGbpUsd                = 35.0;
input double InpAtrMinUsdJpy                = 8.0;
input double InpAtrMaxUsdJpy                = 28.0;
input double InpAtrMinAudUsd                = 6.0;
input double InpAtrMaxAudUsd                = 20.0;

//--- Lot limits
input double InpMinLot                      = 0.01;
input double InpMaxLot                      = 5.00;

//--- Logging
input bool   InpEnableCsvLogging            = true;
input string InpCsvFileName                 = "LeanPullbackEA_Log";

//--- Magic number
input long   InpMagicNumber                 = 20240101;

//--- Now include all modules AFTER inputs are declared
#include "Config.mqh"
#include "Logger.mqh"
#include "DailyState.mqh"
#include "SessionFilter.mqh"
#include "Indicators.mqh"
#include "SignalEngine.mqh"
#include "RiskManager.mqh"
#include "TradeManager.mqh"

//+------------------------------------------------------------------+
//|  GetSymbolConfig — defined here so it can see the input vars     |
//+------------------------------------------------------------------+
bool GetSymbolConfig(const string &symbol, SymbolConfig &cfg)
  {
   string sym = symbol;
   StringToUpper(sym);

   if(StringFind(sym, "EURUSD") >= 0)
     {
      cfg.maxSpreadPips = InpMaxSpreadEurUsd;
      cfg.atrMinPips    = InpAtrMinEurUsd;
      cfg.atrMaxPips    = InpAtrMaxEurUsd;
      return true;
     }
   if(StringFind(sym, "GBPUSD") >= 0)
     {
      cfg.maxSpreadPips = InpMaxSpreadGbpUsd;
      cfg.atrMinPips    = InpAtrMinGbpUsd;
      cfg.atrMaxPips    = InpAtrMaxGbpUsd;
      return true;
     }
   if(StringFind(sym, "USDJPY") >= 0)
     {
      cfg.maxSpreadPips = InpMaxSpreadUsdJpy;
      cfg.atrMinPips    = InpAtrMinUsdJpy;
      cfg.atrMaxPips    = InpAtrMaxUsdJpy;
      return true;
     }
   if(StringFind(sym, "AUDUSD") >= 0)
     {
      cfg.maxSpreadPips = InpMaxSpreadAudUsd;
      cfg.atrMinPips    = InpAtrMinAudUsd;
      cfg.atrMaxPips    = InpAtrMaxAudUsd;
      return true;
     }
   return false;
  }

//+------------------------------------------------------------------+
//|  Module instances                                                 |
//+------------------------------------------------------------------+
CLogger         g_logger;
CDailyState     g_dailyState;
CSessionFilter *g_session    = NULL;
CIndicators     g_indicators;
CSignalEngine   g_signal;
CRiskManager    g_risk;
CTradeManager   g_trade;

datetime g_lastBarTime       = 0;
int      g_totalBarsProcessed  = 0;
int      g_totalSessionBlocked = 0;
int      g_totalSignalEvals    = 0;

//+------------------------------------------------------------------+
//|  OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
  {
   string symbol = Symbol();

   Print("====================================================");
   Print("LeanPullbackEA v1.02 OnInit() | Symbol:", symbol,
         " | Period:", EnumToString(Period()));
   Print("====================================================");

   SymbolConfig cfg;
   if(!GetSymbolConfig(symbol, cfg))
     {
      Print("[INIT FAILED] Symbol not supported: ", symbol);
      return INIT_FAILED;
     }

   if(Period() != PERIOD_M15)
     {
      Print("[INIT FAILED] Must run on M15. Current: ",
            EnumToString(Period()));
      return INIT_FAILED;
     }

   g_logger.Init(InpEnableCsvLogging, InpCsvFileName);

   g_session = new CSessionFilter(InpBrokerUtcOffsetHours);

   datetime brokerNow = TimeCurrent();
   datetime utcNow    = brokerNow - (InpBrokerUtcOffsetHours * 3600);
   g_logger.Info(symbol, StringFormat(
                    "Time | Broker:%s | UTC:%s | Offset:%dh",
                    TimeToString(brokerNow, TIME_DATE|TIME_MINUTES),
                    TimeToString(utcNow,    TIME_DATE|TIME_MINUTES),
                    InpBrokerUtcOffsetHours));

   g_logger.Info(symbol, StringFormat(
                    "London in broker time: %02d:%02d-%02d:%02d",
                    InpLondonStartHour  + InpBrokerUtcOffsetHours,
                    InpLondonStartMinute,
                    InpLondonEndHour    + InpBrokerUtcOffsetHours,
                    InpLondonEndMinute));

   g_logger.Info(symbol, StringFormat(
                    "NewYork in broker time: %02d:%02d-%02d:%02d",
                    InpNewYorkStartHour  + InpBrokerUtcOffsetHours,
                    InpNewYorkStartMinute,
                    InpNewYorkEndHour    + InpBrokerUtcOffsetHours,
                    InpNewYorkEndMinute));

   if(!g_indicators.Init(symbol, InpAtrPeriod, &g_logger))
     {
      g_logger.Error(symbol, "INIT FAILED — indicators");
      return INIT_FAILED;
     }

   g_dailyState.Init(symbol, &g_logger);
   g_signal.Init(symbol, &g_indicators, &g_logger);
   g_risk.Init(symbol, &g_logger);
   g_trade.Init(symbol, &g_logger);

   g_logger.PrintParamSummary(symbol,
                               InpRiskPercent,
                               InpRewardRiskRatio,
                               InpStopBufferPips,
                               InpMinStopPips,
                               InpMaxStopPips,
                               InpBrokerUtcOffsetHours,
                               cfg.maxSpreadPips,
                               cfg.atrMinPips,
                               cfg.atrMaxPips);

   g_logger.Info(symbol, "EA READY");
   Print("[INIT] Completed successfully");
   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
//|  OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   Print("====================================================");
   PrintFormat("SHUTDOWN | Bars:%d | SessionBlocked:%d | Evals:%d",
               g_totalBarsProcessed,
               g_totalSessionBlocked,
               g_totalSignalEvals);
   Print("====================================================");

   g_indicators.Release();
   if(g_session != NULL) { delete g_session; g_session = NULL; }
   g_logger.Info(Symbol(), StringFormat(
                    "Deinit | reason:%d | bars:%d | "
                    "blocked:%d | evals:%d",
                    reason, g_totalBarsProcessed,
                    g_totalSessionBlocked, g_totalSignalEvals));
   g_logger.Deinit();
  }

//+------------------------------------------------------------------+
//|  OnTick                                                           |
//+------------------------------------------------------------------+
void OnTick()
  {
   string symbol = Symbol();

   datetime currentBarTime = iTime(symbol, PERIOD_M15, 0);
   if(currentBarTime == g_lastBarTime)
      return;

   g_lastBarTime = currentBarTime;
   g_totalBarsProcessed++;

   //--- Log first 10 bars + every 100th
   if(g_totalBarsProcessed <= 10 ||
      g_totalBarsProcessed % 100 == 0)
     {
      g_logger.Info(symbol, StringFormat(
                       "BAR #%d | Broker:%s | BarOpen:%s",
                       g_totalBarsProcessed,
                       TimeToString(TimeCurrent(),
                                    TIME_DATE|TIME_MINUTES),
                       TimeToString(currentBarTime,
                                    TIME_DATE|TIME_MINUTES)));
     }

   g_dailyState.CheckAndReset();

   if(g_dailyState.CheckLossLockout(InpMaxDailyLossPercent))
      return;

   //--- Session filter with full logging
   if(!g_session.IsSessionAllowed())
     {
      g_totalSessionBlocked++;
      if(g_totalSessionBlocked <= 20 ||
         g_totalSessionBlocked % 500 == 0)
        {
         int utcH, utcM, dow;
         g_session.GetCurrentUTCTime(utcH, utcM, dow);
         g_logger.Skip(symbol, "N/A", StringFormat(
                          "outside_session | UTC:%02d:%02d | "
                          "DOW:%d | TotalBlocked:%d",
                          utcH, utcM, dow,
                          g_totalSessionBlocked));
        }
      return;
     }

   if(g_trade.HasOpenPosition())
     {
      g_logger.Info(symbol, "Skip — position open");
      return;
     }

   if(g_dailyState.IsSymbolLimitReached(InpMaxTradesPerSymbolPerDay))
     {
      g_logger.Skip(symbol, "N/A", "symbol_trade_limit");
      return;
     }

   if(g_dailyState.IsTotalLimitReached(InpMaxTradesTotalPerDay))
     {
      g_logger.Skip(symbol, "N/A", "total_trade_limit");
      return;
     }

   if(g_trade.IsDuplicateBar())
      return;

   g_totalSignalEvals++;

   SignalResult sig = g_signal.Evaluate();

   if(sig.direction == SIGNAL_NONE)
     {
      if(sig.skipReason != ""                    &&
         sig.skipReason != "no_ema50_touch_long"  &&
         sig.skipReason != "no_ema50_touch_short" &&
         sig.skipReason != "no_bias"              &&
         sig.skipReason != "insufficient_bars")
        {
         g_logger.Skip(symbol, "N/A", sig.skipReason,
                       sig.spread, sig.atrH1,
                       sig.emaH1_200, sig.emaM15_50);
        }
      return;
     }

   double lots = g_risk.CalculateLotSize(sig.stopPips);
   if(lots <= 0)
     {
      g_logger.Error(symbol, "Lot calc failed");
      return;
     }

   string dirStr = (sig.direction == SIGNAL_LONG ? "LONG" : "SHORT");
   g_logger.Trade(symbol, dirStr,
                  sig.entryPrice, sig.stopLoss, sig.takeProfit,
                  lots, sig.spread, sig.atrH1,
                  sig.emaH1_200, sig.emaM15_50);

   bool placed = g_trade.PlaceOrder(sig.direction,
                                     sig.entryPrice,
                                     sig.stopLoss,
                                     sig.takeProfit,
                                     lots);
   if(placed)
      g_dailyState.RecordTrade();
  }

//+------------------------------------------------------------------+
//|  OnTradeTransaction                                               |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest     &request,
                        const MqlTradeResult      &result)
  {
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
     {
      if(trans.deal_type == DEAL_TYPE_BUY ||
         trans.deal_type == DEAL_TYPE_SELL)
        {
         g_logger.Info(Symbol(), StringFormat(
                          "DEAL | #%d | %.5f | %.2f lots | %s",
                          (int)trans.deal, trans.price,
                          trans.volume,
                          (trans.deal_type==DEAL_TYPE_BUY ?
                           "BUY":"SELL")));
        }
     }
  }
//+------------------------------------------------------------------+