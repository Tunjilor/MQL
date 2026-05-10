//+------------------------------------------------------------------+
//|  SignalEngine.mqh                                                 |
//|  Evaluates long/short setup conditions.                           |
//|  VERSION 1.3 — Two-bar confirmation entry                        |
//|                                                                   |
//|  Entry logic:                                                     |
//|    Bar[2] = setup bar  (EMA50 touch + directional close)         |
//|    Bar[1] = confirm bar (closes beyond Bar[2] high/low)          |
//|    Bar[0] = entry bar  (market order at open)                    |
//|                                                                   |
//|  Dependencies (declared in LeanPullbackEA.mq5):                  |
//|    Config.mqh     — GetSymbolConfig(), GetPipSize(),             |
//|                     PriceToPips(), PipsToPrice()                  |
//|    Indicators.mqh — CIndicators                                   |
//|    Logger.mqh     — CLogger                                       |
//|  Inputs required:                                                 |
//|    InpMinDistanceFromH1EMA200Pips                                 |
//|    InpBodyAvgLookback                                             |
//|    InpMinBodyMultiplier                                           |
//|    InpPullbackLookbackBars                                        |
//|    InpStopBufferPips                                              |
//|    InpMinStopPips                                                 |
//|    InpMaxStopPips                                                 |
//|    InpRewardRiskRatio                                             |
//+------------------------------------------------------------------+
#ifndef SIGNALENGINE_MQH
#define SIGNALENGINE_MQH

#include "Indicators.mqh"
#include "Logger.mqh"

//+------------------------------------------------------------------+
//|  SignalDirection enum                                             |
//+------------------------------------------------------------------+
enum SignalDirection
  {
   SIGNAL_NONE  =  0,
   SIGNAL_LONG  =  1,
   SIGNAL_SHORT = -1
  };

//+------------------------------------------------------------------+
//|  SignalResult — full output from one evaluation cycle            |
//+------------------------------------------------------------------+
struct SignalResult
  {
   SignalDirection direction;
   string          skipReason;
   double          entryPrice;
   double          stopLoss;
   double          takeProfit;
   double          stopPips;
   double          spread;
   double          atrH1;
   double          emaH1_200;
   double          emaM15_50;
  };

//+------------------------------------------------------------------+
//|  CSignalEngine class                                              |
//+------------------------------------------------------------------+
class CSignalEngine
  {
private:
   string       m_symbol;
   CIndicators *m_indicators;
   CLogger     *m_logger;

   //+----------------------------------------------------------------+
   //|  GetCurrentSpreadPips                                           |
   //+----------------------------------------------------------------+
   double GetCurrentSpreadPips()
     {
      double ask = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
      double bid = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      return PriceToPips(m_symbol, ask - bid);
     }

   //+----------------------------------------------------------------+
   //|  Log — shorthand info log                                      |
   //+----------------------------------------------------------------+
   void Log(const string &msg)
     {
      if(m_logger != NULL)
         m_logger.Info(m_symbol, msg);
     }

   //+----------------------------------------------------------------+
   //|  EmptyResult — blank SIGNAL_NONE result with reason            |
   //+----------------------------------------------------------------+
   SignalResult EmptyResult(const string &reason)
     {
      SignalResult r;
      r.direction  = SIGNAL_NONE;
      r.skipReason = reason;
      r.entryPrice = 0.0;
      r.stopLoss   = 0.0;
      r.takeProfit = 0.0;
      r.stopPips   = 0.0;
      r.spread     = 0.0;
      r.atrH1      = 0.0;
      r.emaH1_200  = 0.0;
      r.emaM15_50  = 0.0;
      return r;
     }

public:
   //+----------------------------------------------------------------+
   //|  Constructor                                                    |
   //+----------------------------------------------------------------+
   CSignalEngine()
     {
      m_symbol     = "";
      m_indicators = NULL;
      m_logger     = NULL;
     }

   //+----------------------------------------------------------------+
   //|  Init                                                           |
   //+----------------------------------------------------------------+
   void Init(const string &symbol,
             CIndicators  *indicators,
             CLogger      *logger)
     {
      m_symbol     = symbol;
      m_indicators = indicators;
      m_logger     = logger;
     }

   //+------------------------------------------------------------------+
   //|  Evaluate                                                         |
   //|  Called once per new M15 bar.                                    |
   //|  TWO-BAR CONFIRMATION LOGIC:                                     |
   //|    Bar[2] = setup bar  — EMA50 touch + directional close        |
   //|    Bar[1] = confirm bar — closes beyond Bar[2] extreme           |
   //|  All reads use closed bars only. Bar[0] never used.             |
   //+------------------------------------------------------------------+
   SignalResult Evaluate()
     {
      SignalResult r;

      //================================================================
      //  STEP 1 — Guard: indicators initialized
      //================================================================
      if(m_indicators == NULL)
         return EmptyResult("indicators_not_initialized");

      Log("═══ Evaluate() called — new M15 bar ═══");

      //================================================================
      //  STEP 2 — Minimum bars check
      //  Need extra bar now for two-bar confirmation (bar[2] required)
      //================================================================
      int minBars = InpBodyAvgLookback + InpPullbackLookbackBars + 6;
      if(!m_indicators.BarsAvailable(minBars))
        {
         Log(StringFormat("BLOCKED — insufficient bars (need %d)",
                          minBars));
         return EmptyResult("insufficient_bars");
        }

      //================================================================
      //  STEP 3 — Symbol config
      //================================================================
      SymbolConfig cfg;
      if(!GetSymbolConfig(m_symbol, cfg))
        {
         Log("BLOCKED — symbol not supported");
         return EmptyResult("unsupported_symbol");
        }

      //================================================================
      //  STEP 4 — Spread filter
      //================================================================
      double spreadPips = GetCurrentSpreadPips();

      Log(StringFormat("Spread | %.2f pips | Max:%.1f pips",
                       spreadPips, cfg.maxSpreadPips));

      if(spreadPips > cfg.maxSpreadPips)
        {
         Log(StringFormat("SPREAD FAILED (%.2f > %.1f)",
                          spreadPips, cfg.maxSpreadPips));
         r = EmptyResult(StringFormat(
                            "spread_too_high:%.2f", spreadPips));
         r.spread = spreadPips;
         return r;
        }
      Log(StringFormat("Spread PASSED (%.2f pips)", spreadPips));

      //================================================================
      //  STEP 5 — ATR volatility filter (H1 bar[1])
      //================================================================
      double atrRaw = m_indicators.GetAtrH1(1);
      if(atrRaw == EMPTY_VALUE || atrRaw <= 0)
        {
         Log("ATR FAILED — empty value");
         return EmptyResult("atr_unavailable");
        }

      double atrPips = PriceToPips(m_symbol, atrRaw);

      Log(StringFormat("ATR | %.2f pips | Min:%.1f | Max:%.1f",
                       atrPips, cfg.atrMinPips, cfg.atrMaxPips));

      if(atrPips < cfg.atrMinPips)
        {
         Log(StringFormat("ATR FAILED — too low (%.2f < %.1f)",
                          atrPips, cfg.atrMinPips));
         return EmptyResult(StringFormat(
                               "atr_too_low:%.2f", atrPips));
        }
      if(atrPips > cfg.atrMaxPips)
        {
         Log(StringFormat("ATR FAILED — too high (%.2f > %.1f)",
                          atrPips, cfg.atrMaxPips));
         return EmptyResult(StringFormat(
                               "atr_too_high:%.2f", atrPips));
        }
      Log(StringFormat("ATR PASSED (%.2f pips)", atrPips));

      //================================================================
      //  STEP 6 — H1 trend filter
      //================================================================
      double h1Close = m_indicators.GetH1Close(1);
      double emaH1   = m_indicators.GetEmaH1_200(1);

      if(h1Close == 0 || emaH1 == EMPTY_VALUE)
        {
         Log("TREND FAILED — H1 data unavailable");
         return EmptyResult("h1_data_unavailable");
        }

      double distPips = PriceToPips(m_symbol,
                                    MathAbs(h1Close - emaH1));

      Log(StringFormat(
             "Trend | H1Close:%.5f | EMA200:%.5f | "
             "Dist:%.2f pips | DeadZone:%.1f pips",
             h1Close, emaH1, distPips,
             InpMinDistanceFromH1EMA200Pips));

      if(distPips < InpMinDistanceFromH1EMA200Pips)
        {
         Log(StringFormat(
                "TREND FAILED — dead zone (%.2f < %.1f pips)",
                distPips, InpMinDistanceFromH1EMA200Pips));
         return EmptyResult("too_close_to_h1_ema200");
        }

      bool bullishBias = (h1Close > emaH1);
      bool bearishBias = (h1Close < emaH1);

      if(!bullishBias && !bearishBias)
        {
         Log("TREND — no directional bias");
         return EmptyResult("no_bias");
        }

      // Block LONG on GBPUSD — short-only mode
      if(bullishBias && StringFind(m_symbol, "GBPUSD") >= 0)
        {
         Log("LONG blocked on GBPUSD — short-only mode");
         return EmptyResult("gbpusd_long_blocked");
        }

      //================================================================
      //  STEP 7 — M15 EMA50
      //================================================================
      double emaM15 = m_indicators.GetEmaM15_50(1);
      if(emaM15 == EMPTY_VALUE)
        {
         Log("EMA50 FAILED — empty value");
         return EmptyResult("m15_ema50_unavailable");
        }

      //================================================================
      //  STEP 8 — Read BOTH candles
      //
      //  setupBar    = bar[2] — must touch EMA50
      //  confirmBar  = bar[1] — must close beyond setup extreme
      //
      //  Note: EMA50 value at bar[2] time is read from index 2
      //  This prevents using the wrong EMA value for the setup bar
      //================================================================
      double setupOpen    = m_indicators.GetM15Open(2);
      double setupHigh    = m_indicators.GetM15High(2);
      double setupLow     = m_indicators.GetM15Low(2);
      double setupClose   = m_indicators.GetM15Close(2);
      double emaM15_bar2  = m_indicators.GetEmaM15_50(2); // EMA at setup time

      double confOpen     = m_indicators.GetM15Open(1);
      double confHigh     = m_indicators.GetM15High(1);
      double confLow      = m_indicators.GetM15Low(1);
      double confClose    = m_indicators.GetM15Close(1);

      Log(StringFormat(
             "Setup bar[2]  | O:%.5f H:%.5f L:%.5f C:%.5f "
             "| EMA50@bar2:%.5f",
             setupOpen, setupHigh, setupLow, setupClose,
             emaM15_bar2));

      Log(StringFormat(
             "Confirm bar[1]| O:%.5f H:%.5f L:%.5f C:%.5f "
             "| EMA50@bar1:%.5f",
             confOpen, confHigh, confLow, confClose, emaM15));

      //================================================================
      //  STEP 9 — Body size filter on CONFIRMATION bar
      //  We check bar[1] body vs average of bars[2..11]
      //================================================================
      double confBodyPips = MathAbs(confClose - confOpen) /
                            GetPipSize(m_symbol);
      double avgBodyPips  = m_indicators.GetAvgBodySize(
                               2, InpBodyAvgLookback) /
                            GetPipSize(m_symbol);
      double minBodyPips  = avgBodyPips * InpMinBodyMultiplier;

      Log(StringFormat(
             "Body (confirm bar) | %.2f pips | "
             "Avg:%.2f | Min:%.2f pips",
             confBodyPips, avgBodyPips, minBodyPips));

      if(avgBodyPips <= 0)
         return EmptyResult("avg_body_zero");

      if(confBodyPips < minBodyPips)
        {
         Log(StringFormat(
                "BODY FAILED — confirm bar too weak "
                "(%.2f < %.2f pips)",
                confBodyPips, minBodyPips));
         return EmptyResult(StringFormat(
                               "confirm_bar_too_weak:%.2f<%.2f",
                               confBodyPips, minBodyPips));
        }
      Log(StringFormat("Body PASSED (%.2f >= %.2f pips)",
                       confBodyPips, minBodyPips));

      //================================================================
      //  LONG SETUP — TWO-BAR VERSION
      //================================================================
      if(bullishBias)
        {
         Log("--- Evaluating LONG two-bar setup ---");

         //--- Setup bar[2] conditions
         bool setupTouchedEma  = (setupLow  <= emaM15_bar2);
         bool setupBullish     = (setupClose > setupOpen);
         bool setupAboveEma    = (setupClose > emaM15_bar2);

         Log(StringFormat(
                "LONG setup bar[2] | "
                "EMA_touch:%s (low %.5f <= ema %.5f) | "
                "Bullish:%s | Above_EMA:%s",
                (setupTouchedEma ? "YES" : "NO"),
                setupLow, emaM15_bar2,
                (setupBullish    ? "YES" : "NO"),
                (setupAboveEma   ? "YES" : "NO")));

         if(!setupTouchedEma)
           {
            Log(StringFormat(
                   "LONG FAILED — setup bar[2] did not touch EMA50 "
                   "(low %.5f > ema %.5f)",
                   setupLow, emaM15_bar2));
            return EmptyResult("setup_no_ema50_touch_long");
           }
         if(!setupBullish)
           {
            Log("LONG FAILED — setup bar[2] not bullish");
            return EmptyResult("setup_bar_not_bullish");
           }
         if(!setupAboveEma)
           {
            Log("LONG FAILED — setup bar[2] closed below EMA50");
            return EmptyResult("setup_close_not_above_ema50");
           }

         Log("LONG setup bar[2] ALL PASSED");

         //--- Confirmation bar[1] conditions
         bool confBullish      = (confClose  > confOpen);
         bool confAboveSetup   = (confClose  > setupHigh);

         Log(StringFormat(
                "LONG confirm bar[1] | "
                "Bullish:%s | "
                "Close_above_setup_high:%s (%.5f > %.5f)",
                (confBullish    ? "YES" : "NO"),
                (confAboveSetup ? "YES" : "NO"),
                confClose, setupHigh));

         if(!confBullish)
           {
            Log("LONG FAILED — confirm bar[1] not bullish");
            return EmptyResult("confirm_bar_not_bullish");
           }
         if(!confAboveSetup)
           {
            Log(StringFormat(
                   "LONG FAILED — confirm bar[1] close %.5f "
                   "did not exceed setup high %.5f",
                   confClose, setupHigh));
            return EmptyResult("confirm_close_not_above_setup_high");
           }

         Log("LONG confirm bar[1] ALL PASSED");

         //--- SL: lowest low of pullback window
         //--- Lookback covers bars[1..PullbackLookbackBars+1]
         //--- +1 because setup bar is now at index 2
         double pullbackLow = m_indicators.GetLowestLow(
                                 1, InpPullbackLookbackBars + 1);
         double slPrice     = pullbackLow -
                              PipsToPrice(m_symbol,
                                          InpStopBufferPips);
         double entry       = SymbolInfoDouble(m_symbol,
                                               SYMBOL_ASK);
         double stopPips    = (entry - slPrice) /
                              GetPipSize(m_symbol);

         Log(StringFormat(
                "LONG SL | PullbackLow:%.5f | Buffer:%.1f pips | "
                "SL:%.5f | Entry(Ask):%.5f | Stop:%.2f pips",
                pullbackLow, InpStopBufferPips,
                slPrice, entry, stopPips));

         if(stopPips < InpMinStopPips)
           {
            Log(StringFormat(
                   "Stop %.2f < min %.1f — expanding to minimum",
                   stopPips, InpMinStopPips));
            slPrice  = entry - PipsToPrice(m_symbol,
                                           InpMinStopPips);
            stopPips = InpMinStopPips;
           }
         if(stopPips > InpMaxStopPips)
           {
            Log(StringFormat(
                   "LONG FAILED — stop %.2f > max %.1f pips",
                   stopPips, InpMaxStopPips));
            return EmptyResult(StringFormat(
                                  "stop_too_large:%.2f",
                                  stopPips));
           }

         int digits = (int)SymbolInfoInteger(m_symbol,
                                             SYMBOL_DIGITS);
         r.direction  = SIGNAL_LONG;
         r.entryPrice = entry;
         r.stopLoss   = NormalizeDouble(slPrice, digits);
         r.takeProfit = NormalizeDouble(
                           entry + PipsToPrice(m_symbol,
                                   stopPips * InpRewardRiskRatio),
                           digits);
         r.stopPips   = stopPips;
         r.spread     = spreadPips;
         r.atrH1      = atrPips;
         r.emaH1_200  = emaH1;
         r.emaM15_50  = emaM15;
         r.skipReason = "";

         Log(StringFormat(
                "LONG CONFIRMED | Entry:%.5f | SL:%.5f | "
                "TP:%.5f | Stop:%.2f pips | RR:1:%.1f",
                r.entryPrice, r.stopLoss, r.takeProfit,
                r.stopPips, InpRewardRiskRatio));
         return r;
        }

      //================================================================
      //  SHORT SETUP — TWO-BAR VERSION
      //================================================================
      if(bearishBias)
        {
         Log("--- Evaluating SHORT two-bar setup ---");

         //--- Setup bar[2] conditions
         bool setupTouchedEma  = (setupHigh  >= emaM15_bar2);
         bool setupBearish     = (setupClose  < setupOpen);
         bool setupBelowEma    = (setupClose  < emaM15_bar2);

         Log(StringFormat(
                "SHORT setup bar[2] | "
                "EMA_touch:%s (high %.5f >= ema %.5f) | "
                "Bearish:%s | Below_EMA:%s",
                (setupTouchedEma ? "YES" : "NO"),
                setupHigh, emaM15_bar2,
                (setupBearish    ? "YES" : "NO"),
                (setupBelowEma   ? "YES" : "NO")));

         if(!setupTouchedEma)
           {
            Log(StringFormat(
                   "SHORT FAILED — setup bar[2] did not touch EMA50 "
                   "(high %.5f < ema %.5f)",
                   setupHigh, emaM15_bar2));
            return EmptyResult("setup_no_ema50_touch_short");
           }
         if(!setupBearish)
           {
            Log("SHORT FAILED — setup bar[2] not bearish");
            return EmptyResult("setup_bar_not_bearish");
           }
         if(!setupBelowEma)
           {
            Log("SHORT FAILED — setup bar[2] closed above EMA50");
            return EmptyResult("setup_close_not_below_ema50");
           }

         Log("SHORT setup bar[2] ALL PASSED");

         //--- Confirmation bar[1] conditions
         bool confBearish      = (confClose  < confOpen);
         bool confBelowSetup   = (confClose  < setupLow);

         Log(StringFormat(
                "SHORT confirm bar[1] | "
                "Bearish:%s | "
                "Close_below_setup_low:%s (%.5f < %.5f)",
                (confBearish    ? "YES" : "NO"),
                (confBelowSetup ? "YES" : "NO"),
                confClose, setupLow));

         if(!confBearish)
           {
            Log("SHORT FAILED — confirm bar[1] not bearish");
            return EmptyResult("confirm_bar_not_bearish");
           }
         if(!confBelowSetup)
           {
            Log(StringFormat(
                   "SHORT FAILED — confirm bar[1] close %.5f "
                   "did not break below setup low %.5f",
                   confClose, setupLow));
            return EmptyResult("confirm_close_not_below_setup_low");
           }

         Log("SHORT confirm bar[1] ALL PASSED");

         //--- SL: highest high of pullback window
         double pullbackHigh = m_indicators.GetHighestHigh(
                                  1, InpPullbackLookbackBars + 1);
         double slPrice      = pullbackHigh +
                               PipsToPrice(m_symbol,
                                           InpStopBufferPips);
         double entry        = SymbolInfoDouble(m_symbol,
                                                SYMBOL_BID);
         double stopPips     = (slPrice - entry) /
                               GetPipSize(m_symbol);

         Log(StringFormat(
                "SHORT SL | PullbackHigh:%.5f | Buffer:%.1f pips | "
                "SL:%.5f | Entry(Bid):%.5f | Stop:%.2f pips",
                pullbackHigh, InpStopBufferPips,
                slPrice, entry, stopPips));

         if(stopPips < InpMinStopPips)
           {
            Log(StringFormat(
                   "Stop %.2f < min %.1f — expanding to minimum",
                   stopPips, InpMinStopPips));
            slPrice  = entry + PipsToPrice(m_symbol,
                                           InpMinStopPips);
            stopPips = InpMinStopPips;
           }
         if(stopPips > InpMaxStopPips)
           {
            Log(StringFormat(
                   "SHORT FAILED — stop %.2f > max %.1f pips",
                   stopPips, InpMaxStopPips));
            return EmptyResult(StringFormat(
                                  "stop_too_large:%.2f",
                                  stopPips));
           }

         int digits = (int)SymbolInfoInteger(m_symbol,
                                             SYMBOL_DIGITS);
         r.direction  = SIGNAL_SHORT;
         r.entryPrice = entry;
         r.stopLoss   = NormalizeDouble(slPrice, digits);
         r.takeProfit = NormalizeDouble(
                           entry - PipsToPrice(m_symbol,
                                   stopPips * InpRewardRiskRatio),
                           digits);
         r.stopPips   = stopPips;
         r.spread     = spreadPips;
         r.atrH1      = atrPips;
         r.emaH1_200  = emaH1;
         r.emaM15_50  = emaM15;
         r.skipReason = "";

         Log(StringFormat(
                "SHORT CONFIRMED | Entry:%.5f | SL:%.5f | "
                "TP:%.5f | Stop:%.2f pips | RR:1:%.1f",
                r.entryPrice, r.stopLoss, r.takeProfit,
                r.stopPips, InpRewardRiskRatio));
         return r;
        }

      return EmptyResult("no_signal");
     }
  };

#endif // SIGNALENGINE_MQH