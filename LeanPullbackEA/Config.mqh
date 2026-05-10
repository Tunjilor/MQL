//+------------------------------------------------------------------+
//|  Config.mqh                                                       |
//|  Symbol-specific config lookups and pip/price helpers.            |
//|  NOTE: All input declarations have moved to LeanPullbackEA.mq5   |
//+------------------------------------------------------------------+
#ifndef CONFIG_MQH
#define CONFIG_MQH

//+------------------------------------------------------------------+
//|  SymbolConfig — per-symbol thresholds                             |
//+------------------------------------------------------------------+
struct SymbolConfig
  {
   double   maxSpreadPips;
   double   atrMinPips;
   double   atrMaxPips;
  };

//+------------------------------------------------------------------+
//|  GetSymbolConfig                                                  |
//|  Populated from inputs passed in — defined in main .mq5 file     |
//+------------------------------------------------------------------+
bool GetSymbolConfig(const string &symbol, SymbolConfig &cfg);

//+------------------------------------------------------------------+
//|  GetPipSize                                                       |
//+------------------------------------------------------------------+
double GetPipSize(const string &symbol)
  {
   double point  = SymbolInfoDouble(symbol, SYMBOL_POINT);
   int    digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   if(digits == 5 || digits == 3)
      return point * 10.0;
   return point;
  }

//+------------------------------------------------------------------+
//|  PriceToPips                                                      |
//+------------------------------------------------------------------+
double PriceToPips(const string &symbol, const double priceDistance)
  {
   double pipSize = GetPipSize(symbol);
   if(pipSize <= 0) return 0;
   return MathAbs(priceDistance) / pipSize;
  }

//+------------------------------------------------------------------+
//|  PipsToPrice                                                      |
//+------------------------------------------------------------------+
double PipsToPrice(const string &symbol, const double pips)
  {
   return pips * GetPipSize(symbol);
  }

#endif // CONFIG_MQH