//+------------------------------------------------------------------+
//|                                              SessionFilter.mqh   |
//+------------------------------------------------------------------+
#ifndef SESSIONFILTER_MQH
#define SESSIONFILTER_MQH

class CSessionFilter
  {
private:
   int m_brokerUtcOffsetHours;

public:
   CSessionFilter(const int utcOffsetHours)
     {
      m_brokerUtcOffsetHours = utcOffsetHours;
     }

   void GetCurrentUTCTime(int &utcHour, int &utcMinute, int &dayOfWeek)
     {
      datetime brokerNow = TimeCurrent();
      datetime utcNow = brokerNow - (m_brokerUtcOffsetHours * 3600);

      MqlDateTime dt;
      TimeToStruct(utcNow, dt);

      utcHour   = dt.hour;
      utcMinute = dt.min;
      dayOfWeek = dt.day_of_week;
     }

   bool IsSessionAllowed()
     {
      int utcHour, utcMinute, dayOfWeek;
      GetCurrentUTCTime(utcHour, utcMinute, dayOfWeek);

      // Friday cutoff
      if(dayOfWeek == 5)
        {
         if(utcHour > InpFridayCutoffHour ||
            (utcHour == InpFridayCutoffHour && utcMinute >= InpFridayCutoffMinute))
            return false;
        }

      // Saturday blocked
      if(dayOfWeek == 6)
         return false;

      // Sunday blocked
      if(dayOfWeek == 0)
         return false;

      int totalMinutes = utcHour * 60 + utcMinute;

      int londonStart  = InpLondonStartHour * 60 + InpLondonStartMinute;
      int londonEnd    = InpLondonEndHour   * 60 + InpLondonEndMinute;

      int nyStart      = InpNewYorkStartHour * 60 + InpNewYorkStartMinute;
      int nyEnd        = InpNewYorkEndHour   * 60 + InpNewYorkEndMinute;

      bool londonOk = (totalMinutes >= londonStart && totalMinutes <= londonEnd);
      bool newYorkOk = (totalMinutes >= nyStart && totalMinutes <= nyEnd);

      return (londonOk || newYorkOk);
     }
  };

#endif