//+------------------------------------------------------------------+
//|                                               TradeManager.mqh   |
//+------------------------------------------------------------------+
#ifndef TRADEMANAGER_MQH
#define TRADEMANAGER_MQH

#include <Trade/Trade.mqh>

class CTradeManager
  {
private:
   string   m_symbol;
   CLogger *m_logger;
   CTrade   m_trade;
   datetime m_lastSignalBarTime;

public:
   CTradeManager()
     {
      m_symbol = "";
      m_logger = NULL;
      m_lastSignalBarTime = 0;
     }

   void Init(const string symbol, CLogger *logger)
     {
      m_symbol = symbol;
      m_logger = logger;
      m_lastSignalBarTime = 0;

      m_trade.SetExpertMagicNumber(InpMagicNumber);
      m_trade.SetDeviationInPoints(10);
     }

   bool HasOpenPosition()
     {
      for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0)
            continue;

         if(PositionSelectByTicket(ticket))
           {
            string posSymbol = PositionGetString(POSITION_SYMBOL);
            long   posMagic  = PositionGetInteger(POSITION_MAGIC);

            if(posSymbol == m_symbol && posMagic == InpMagicNumber)
               return true;
           }
        }

      return false;
     }

   bool IsDuplicateBar()
     {
      datetime currentBar = iTime(m_symbol, PERIOD_M15, 0);
      return (currentBar == m_lastSignalBarTime);
     }

   bool PlaceOrder(const int direction,
                   const double entryPrice,
                   const double stopLoss,
                   const double takeProfit,
                   const double lots)
     {
      bool ok = false;

      if(direction == SIGNAL_LONG)
         ok = m_trade.Buy(lots, m_symbol, 0.0, stopLoss, takeProfit, "LeanPullbackEA Buy");
      else if(direction == SIGNAL_SHORT)
         ok = m_trade.Sell(lots, m_symbol, 0.0, stopLoss, takeProfit, "LeanPullbackEA Sell");
      else
        {
         if(m_logger != NULL)
            m_logger.Error(m_symbol, "PlaceOrder: invalid direction");
         return false;
        }

      if(ok)
        {
         m_lastSignalBarTime = iTime(m_symbol, PERIOD_M15, 0);

         if(m_logger != NULL)
            m_logger.Info(m_symbol,
                          StringFormat("Order placed successfully. Ticket=%I64u",
                                       m_trade.ResultOrder()));
        }
      else
        {
         if(m_logger != NULL)
            m_logger.Error(m_symbol,
                           StringFormat("Order failed. Retcode=%d | %s",
                                        (int)m_trade.ResultRetcode(),
                                        m_trade.ResultRetcodeDescription()));
        }

      return ok;
     }
  };

#endif