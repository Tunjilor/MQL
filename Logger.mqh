//+------------------------------------------------------------------+
//|                                                     Logger.mqh   |
//+------------------------------------------------------------------+
#ifndef LOGGER_MQH
#define LOGGER_MQH

class CLogger
  {
private:
   bool   m_enableCsv;
   string m_csvFileName;

public:
   CLogger()
     {
      m_enableCsv = false;
      m_csvFileName = "";
     }

   bool Init(const bool enableCsvLogging, const string csvFileName)
     {
      m_enableCsv  = enableCsvLogging;
      m_csvFileName = csvFileName;
      return true;
     }

   void Deinit()
     {
     }

   void WriteCSV(const string line)
     {
      if(!m_enableCsv)
         return;

      int handle = FileOpen(m_csvFileName,
                            FILE_READ | FILE_WRITE | FILE_TXT | FILE_SHARE_WRITE);
      if(handle == INVALID_HANDLE)
         return;

      FileSeek(handle, 0, SEEK_END);
      FileWriteString(handle, line + "\r\n");
      FileClose(handle);
     }

   void Info(const string symbol, const string message)
     {
      string line = StringFormat("[INFO] %s | %s", symbol, message);
      Print(line);
      WriteCSV(line);
     }

   void Warn(const string symbol, const string message)
     {
      string line = StringFormat("[WARN] %s | %s", symbol, message);
      Print(line);
      WriteCSV(line);
     }

   void Error(const string symbol, const string message)
     {
      string line = StringFormat("[ERROR] %s | %s", symbol, message);
      Print(line);
      WriteCSV(line);
     }

   void Skip(const string symbol,
             const string direction,
             const string reason,
             const double spread=0.0,
             const double atr=0.0,
             const double emaH1=0.0,
             const double emaM15=0.0)
     {
      string line = StringFormat("[SKIP] %s | %s | %s | spread=%.2f | atr=%.2f | h1ema=%.5f | m15ema=%.5f",
                                 symbol, direction, reason, spread, atr, emaH1, emaM15);
      Print(line);
      WriteCSV(line);
     }

   void Trade(const string symbol,
              const string direction,
              const double entryPrice,
              const double stopLoss,
              const double takeProfit,
              const double lots,
              const double spread=0.0,
              const double atr=0.0,
              const double emaH1=0.0,
              const double emaM15=0.0)
     {
      string line = StringFormat("[TRADE] %s | %s | entry=%.5f | sl=%.5f | tp=%.5f | lots=%.2f | spread=%.2f | atr=%.2f | h1ema=%.5f | m15ema=%.5f",
                                 symbol, direction, entryPrice, stopLoss, takeProfit, lots,
                                 spread, atr, emaH1, emaM15);
      Print(line);
      WriteCSV(line);
     }

   void PrintParamSummary(const string symbol,
                          const double riskPercent,
                          const double rewardRiskRatio,
                          const double stopBufferPips,
                          const double minStopPips,
                          const double maxStopPips,
                          const int brokerUtcOffsetHours,
                          const double maxSpreadPips,
                          const double atrMinPips,
                          const double atrMaxPips)
     {
      string line = StringFormat("[PARAMS] %s | risk=%.2f | rr=%.2f | stopBuf=%.2f | minStop=%.2f | maxStop=%.2f | utcOffset=%d | maxSpread=%.2f | atrMin=%.2f | atrMax=%.2f",
                                 symbol, riskPercent, rewardRiskRatio, stopBufferPips,
                                 minStopPips, maxStopPips, brokerUtcOffsetHours,
                                 maxSpreadPips, atrMinPips, atrMaxPips);
      Print(line);
      WriteCSV(line);
     }
  };

#endif