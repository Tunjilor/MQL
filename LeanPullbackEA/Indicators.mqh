//+------------------------------------------------------------------+
//|  Indicators.mqh                                                   |
//|  Creates and manages indicator handles.                           |
//|  Provides typed access to EMA, ATR, and bar data.                |
//|  ALL signal reads use closed bars (index >= 1).                  |
//|  Bar index [0] is the forming bar — never used for signals.      |
//+------------------------------------------------------------------+
#ifndef INDICATORS_MQH
#define INDICATORS_MQH

#include "Logger.mqh"

class CIndicators
  {
private:
   string   m_symbol;
   int      m_handleEmaH1_200;
   int      m_handleEmaM15_50;
   int      m_handleAtrH1;
   CLogger *m_logger;

public:
   //+----------------------------------------------------------------+
   //|  Constructor                                                    |
   //+----------------------------------------------------------------+
   CIndicators()
     {
      m_symbol          = "";
      m_handleEmaH1_200 = INVALID_HANDLE;
      m_handleEmaM15_50 = INVALID_HANDLE;
      m_handleAtrH1     = INVALID_HANDLE;
      m_logger          = NULL;
     }

   //+----------------------------------------------------------------+
   //|  Init — creates all indicator handles                          |
   //|  Returns false if any handle creation fails.                   |
   //+----------------------------------------------------------------+
   bool Init(const string &symbol,
             const int     atrPeriod,
             CLogger      *logger)
     {
      m_symbol = symbol;
      m_logger = logger;

      m_handleEmaH1_200 = iMA(symbol, PERIOD_H1,  200, 0,
                               MODE_EMA, PRICE_CLOSE);
      if(m_handleEmaH1_200 == INVALID_HANDLE)
        {
         if(m_logger)
            m_logger.Error(symbol,
                           "Failed to create H1 EMA200 handle");
         return false;
        }

      m_handleEmaM15_50 = iMA(symbol, PERIOD_M15, 50, 0,
                               MODE_EMA, PRICE_CLOSE);
      if(m_handleEmaM15_50 == INVALID_HANDLE)
        {
         if(m_logger)
            m_logger.Error(symbol,
                           "Failed to create M15 EMA50 handle");
         return false;
        }

      m_handleAtrH1 = iATR(symbol, PERIOD_H1, atrPeriod);
      if(m_handleAtrH1 == INVALID_HANDLE)
        {
         if(m_logger)
            m_logger.Error(symbol,
                           "Failed to create H1 ATR handle");
         return false;
        }

      if(m_logger)
         m_logger.Info(symbol,
                       "All indicator handles created successfully");
      return true;
     }

   //+----------------------------------------------------------------+
   //|  Release — call from OnDeinit                                  |
   //+----------------------------------------------------------------+
   void Release()
     {
      if(m_handleEmaH1_200 != INVALID_HANDLE)
        {
         IndicatorRelease(m_handleEmaH1_200);
         m_handleEmaH1_200 = INVALID_HANDLE;
        }
      if(m_handleEmaM15_50 != INVALID_HANDLE)
        {
         IndicatorRelease(m_handleEmaM15_50);
         m_handleEmaM15_50 = INVALID_HANDLE;
        }
      if(m_handleAtrH1 != INVALID_HANDLE)
        {
         IndicatorRelease(m_handleAtrH1);
         m_handleAtrH1 = INVALID_HANDLE;
        }
     }

   //+----------------------------------------------------------------+
   //|  BarsAvailable — confirms enough bars exist before signals     |
   //+----------------------------------------------------------------+
   bool BarsAvailable(const int minBars)
     {
      return (Bars(m_symbol, PERIOD_M15) >= minBars &&
              Bars(m_symbol, PERIOD_H1)  >= 200);
     }

   //+----------------------------------------------------------------+
   //|  GetEmaH1_200 — H1 EMA200 at bar index                        |
   //|  Use bar=1 for last closed H1 bar (safe for signals)           |
   //+----------------------------------------------------------------+
   double GetEmaH1_200(const int bar = 1)
     {
      double buf[];
      ArraySetAsSeries(buf, true);
      if(CopyBuffer(m_handleEmaH1_200, 0, 0, bar + 1, buf) <= 0)
        {
         if(m_logger)
            m_logger.Error(m_symbol,
                           "CopyBuffer failed: H1 EMA200");
         return EMPTY_VALUE;
        }
      return buf[bar];
     }

   //+----------------------------------------------------------------+
   //|  GetEmaM15_50 — M15 EMA50 at bar index                        |
   //|  Use bar=1 for last closed M15 bar                            |
   //+----------------------------------------------------------------+
   double GetEmaM15_50(const int bar = 1)
     {
      double buf[];
      ArraySetAsSeries(buf, true);
      if(CopyBuffer(m_handleEmaM15_50, 0, 0, bar + 1, buf) <= 0)
        {
         if(m_logger)
            m_logger.Error(m_symbol,
                           "CopyBuffer failed: M15 EMA50");
         return EMPTY_VALUE;
        }
      return buf[bar];
     }

   //+----------------------------------------------------------------+
   //|  GetAtrH1 — H1 ATR at bar index                               |
   //|  Use bar=1 for last closed H1 bar                             |
   //+----------------------------------------------------------------+
   double GetAtrH1(const int bar = 1)
     {
      double buf[];
      ArraySetAsSeries(buf, true);
      if(CopyBuffer(m_handleAtrH1, 0, 0, bar + 1, buf) <= 0)
        {
         if(m_logger)
            m_logger.Error(m_symbol,
                           "CopyBuffer failed: H1 ATR");
         return EMPTY_VALUE;
        }
      return buf[bar];
     }

   //+----------------------------------------------------------------+
   //|  GetH1Close — close price of H1 bar at index                  |
   //+----------------------------------------------------------------+
   double GetH1Close(const int bar = 1)
     {
      return iClose(m_symbol, PERIOD_H1, bar);
     }

   //+----------------------------------------------------------------+
   //|  GetM15Close — close price of M15 bar at index                |
   //+----------------------------------------------------------------+
   double GetM15Close(const int bar)
     {
      return iClose(m_symbol, PERIOD_M15, bar);
     }

   //+----------------------------------------------------------------+
   //|  GetM15Open — open price of M15 bar at index                  |
   //+----------------------------------------------------------------+
   double GetM15Open(const int bar)
     {
      return iOpen(m_symbol, PERIOD_M15, bar);
     }

   //+----------------------------------------------------------------+
   //|  GetM15High — high price of M15 bar at index                  |
   //+----------------------------------------------------------------+
   double GetM15High(const int bar)
     {
      return iHigh(m_symbol, PERIOD_M15, bar);
     }

   //+----------------------------------------------------------------+
   //|  GetM15Low — low price of M15 bar at index                    |
   //+----------------------------------------------------------------+
   double GetM15Low(const int bar)
     {
      return iLow(m_symbol, PERIOD_M15, bar);
     }

   //+----------------------------------------------------------------+
   //|  GetAvgBodySize                                                 |
   //|  Mean absolute body size over [startBar .. startBar+count-1]  |
   //|  Returns price units (not pips).                               |
   //|  For trigger candle = bar[1], use startBar=2, count=lookback  |
   //+----------------------------------------------------------------+
   double GetAvgBodySize(const int startBar, const int count)
     {
      if(count <= 0)
         return 0.0;

      double total = 0.0;
      for(int i = startBar; i < startBar + count; i++)
        {
         total += MathAbs(iClose(m_symbol, PERIOD_M15, i) -
                          iOpen(m_symbol,  PERIOD_M15, i));
        }
      return total / (double)count;
     }

   //+----------------------------------------------------------------+
   //|  GetLowestLow                                                   |
   //|  Lowest low across M15 bars [startBar .. endBar] inclusive    |
   //+----------------------------------------------------------------+
   double GetLowestLow(const int startBar, const int endBar)
     {
      double lowest = DBL_MAX;
      for(int i = startBar; i <= endBar; i++)
        {
         double lo = iLow(m_symbol, PERIOD_M15, i);
         if(lo < lowest)
            lowest = lo;
        }
      return lowest;
     }

   //+----------------------------------------------------------------+
   //|  GetHighestHigh                                                 |
   //|  Highest high across M15 bars [startBar .. endBar] inclusive  |
   //+----------------------------------------------------------------+
   double GetHighestHigh(const int startBar, const int endBar)
     {
      double highest = -DBL_MAX;
      for(int i = startBar; i <= endBar; i++)
        {
         double hi = iHigh(m_symbol, PERIOD_M15, i);
         if(hi > highest)
            highest = hi;
        }
      return highest;
     }
  };

#endif // INDICATORS_MQH