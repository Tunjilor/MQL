//+------------------------------------------------------------------+
//|                                                 DailyState.mqh   |
//+------------------------------------------------------------------+
#ifndef DAILYSTATE_MQH
#define DAILYSTATE_MQH

class CDailyState
  {
private:
   string   m_symbol;
   CLogger *m_logger;
   int      m_currentDayOfYear;
   int      m_symbolTradesToday;
   int      m_totalTradesToday;
   double   m_startingEquityToday;
   bool     m_lossLockout;

public:
   CDailyState()
     {
      m_symbol = "";
      m_logger = NULL;
      m_currentDayOfYear = -1;
      m_symbolTradesToday = 0;
      m_totalTradesToday = 0;
      m_startingEquityToday = 0.0;
      m_lossLockout = false;
     }

   void Init(const string symbol, CLogger *logger)
     {
      m_symbol = symbol;
      m_logger = logger;

      datetime now = TimeCurrent();
      MqlDateTime dt;
      TimeToStruct(now, dt);

      m_currentDayOfYear = dt.day_of_year;
      m_symbolTradesToday = 0;
      m_totalTradesToday = 0;
      m_startingEquityToday = AccountInfoDouble(ACCOUNT_EQUITY);
      m_lossLockout = false;
     }

   void CheckAndReset()
     {
      datetime now = TimeCurrent();
      MqlDateTime dt;
      TimeToStruct(now, dt);

      if(dt.day_of_year != m_currentDayOfYear)
        {
         m_currentDayOfYear = dt.day_of_year;
         m_symbolTradesToday = 0;
         m_totalTradesToday = 0;
         m_startingEquityToday = AccountInfoDouble(ACCOUNT_EQUITY);
         m_lossLockout = false;

         if(m_logger != NULL)
            m_logger.Info(m_symbol, "Daily state reset.");
        }
     }

   bool CheckLossLockout(const double maxDailyLossPercent)
     {
      if(m_lossLockout)
         return true;

      if(m_startingEquityToday <= 0.0)
         return false;

      double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
      double drawdownPct = ((m_startingEquityToday - currentEquity) / m_startingEquityToday) * 100.0;

      if(drawdownPct >= maxDailyLossPercent)
        {
         m_lossLockout = true;
         if(m_logger != NULL)
            m_logger.Warn(m_symbol,
                          StringFormat("Daily loss lockout triggered. Drawdown=%.2f%%", drawdownPct));
         return true;
        }

      return false;
     }

   bool IsSymbolLimitReached(const int maxTradesPerSymbolPerDay)
     {
      return (m_symbolTradesToday >= maxTradesPerSymbolPerDay);
     }

   bool IsTotalLimitReached(const int maxTradesTotalPerDay)
     {
      return (m_totalTradesToday >= maxTradesTotalPerDay);
     }

   void RecordTrade()
     {
      m_symbolTradesToday++;
      m_totalTradesToday++;

      if(m_logger != NULL)
         m_logger.Info(m_symbol,
                       StringFormat("Trade counters updated. Symbol=%d Total=%d",
                                    m_symbolTradesToday, m_totalTradesToday));
     }
  };

#endif