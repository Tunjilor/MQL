//+------------------------------------------------------------------+
//|                                                RiskManager.mqh   |
//+------------------------------------------------------------------+
#ifndef RISKMANAGER_MQH
#define RISKMANAGER_MQH

class CRiskManager
  {
private:
   string   m_symbol;
   CLogger *m_logger;

public:
   CRiskManager()
     {
      m_symbol = "";
      m_logger = NULL;
     }

   void Init(const string symbol, CLogger *logger)
     {
      m_symbol = symbol;
      m_logger = logger;
     }

   double CalculateLotSize(const double stopPips)
     {
      if(stopPips <= 0.0)
        {
         if(m_logger != NULL)
            m_logger.Error(m_symbol, "CalculateLotSize: stopPips <= 0");
         return 0.0;
        }

      double equity   = AccountInfoDouble(ACCOUNT_EQUITY);
      double riskAmt  = equity * (InpRiskPercent / 100.0);

      double tickVal  = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_SIZE);
      double pipSize  = GetPipSize(m_symbol);

      if(tickVal <= 0.0 || tickSize <= 0.0 || pipSize <= 0.0)
        {
         if(m_logger != NULL)
            m_logger.Error(m_symbol, "CalculateLotSize: invalid tick/pip data");
         return 0.0;
        }

      double pipValuePerLot = (pipSize / tickSize) * tickVal;
      if(pipValuePerLot <= 0.0)
        {
         if(m_logger != NULL)
            m_logger.Error(m_symbol, "CalculateLotSize: pipValuePerLot <= 0");
         return 0.0;
        }

      double rawLots = riskAmt / (stopPips * pipValuePerLot);

      double lotStep = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP);
      double minLot  = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
      double maxLot  = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MAX);

      if(lotStep <= 0.0)
         lotStep = 0.01;

      double lots = MathFloor(rawLots / lotStep) * lotStep;

      lots = MathMax(lots, InpMinLot);
      lots = MathMin(lots, InpMaxLot);
      lots = MathMax(lots, minLot);
      lots = MathMin(lots, maxLot);

      if(lots < minLot)
        {
         if(m_logger != NULL)
            m_logger.Warn(m_symbol,
                          StringFormat("Lot size %.4f below broker minimum %.4f. Using minimum.",
                                       lots, minLot));
         lots = minLot;
        }

      return NormalizeDouble(lots, 2);
     }
  };

#endif