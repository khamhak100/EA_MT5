#property strict
#property version "29.541"
#property description "v29.5.4 FIXED (production): compile-safe full file. Fix NoReentrySameBar (block only after a real entry attempt in the bar). Includes OpenTrade/ManageOpenPositions/OnTradeTransaction. AutoSessions + safe auto-gap rollover kept."

#include <Trade\Trade.mqh>
CTrade trade;

//======================== Inputs ========================
input group "=== 0) Symbol / Trade ==="
input string AllowedSymbols = "XAUUSD.iux";
input int    MagicBase = 282000;
input bool   UseAutoMagic = true;

// Lots
input group "=== 0a) Lot sizing ==="
input bool   UseEquityTierLot = true;
input bool   UseStepLot = true;
input double FixedLot = 0.01;
input double LotPer1000 = 0.01;
input double MaxLot = 0.10;
input double MinLotOverride = 0.0;

// Equity-tier schedule
input double Tier1_EqMin = 100.0;
input double Tier1_EqMax = 399.99;
input double Tier1_Lot   = 0.01;

input double Tier2_EqMin = 400.0;
input double Tier2_EqMax = 999.99;
input double Tier2_Lot   = 0.02;

input double Tier3_EqMin = 1000.0;
input double Tier3_EqMax = 1599.99;
input double Tier3_Lot   = 0.03;

input double Tier4_EqMin = 1600.0;
input double Tier4_EqMax = 2999.99;
input double Tier4_Lot   = 0.05;

input double Tier5_EqMin = 3000.0;
input double Tier5_EqMax = 4999.99;
input double Tier5_Lot   = 0.08;

input double Tier6_EqMin = 5000.0;
input double Tier6_EqMax = 1.0e12;
input double Tier6_Lot   = 0.10;

// Add-on
input group "=== 0b) Add-on ==="
input bool   UseAddOn = false;
input int    MaxOpenPositions = 1;
input double AddOnLotFactor = 0.50;
input double AddOn_MinLockedProfit_Price = 1.0;
input double AddOn_MinAdditionalMove_Price = 1.5;
input int    AddOn_CooldownBars = 2;

input group "=== 1) Timeframes ==="
input ENUM_TIMEFRAMES EntryTF = PERIOD_M15;
input ENUM_TIMEFRAMES TrendTF = PERIOD_H1;

input group "=== 2) Trend Filter (TrendTF) ==="
input int TrendEMA_Fast = 50;
input int TrendEMA_Slow = 200;
input double MinTrendEMADistance_Price = 10.0;

input group "=== 2b) ATR Regime Filter (tiered) ==="
input bool UseATRFilter = true;
input ENUM_TIMEFRAMES ATR_TF = PERIOD_M15;
input int ATR_Period = 14;
input double ATR_Min_Price = 2.5;
input double ATR_MaxForAddOn_Price = 30.0;
input double ATR_MaxForTrading_Price = 40.0;
input double ATR_HighLotFactor = 0.50;

input group "=== 3) Entry (EntryTF) ==="
input int EntryEMA = 20;
input int RSI_Period = 14;
input double RSI_Buy_Min = 48.0;
input double RSI_Buy_Max = 58.0;
input double RSI_Sell_Min = 42.0;
input double RSI_Sell_Max = 52.0;
input double MaxDistanceFromEntryEMA_Price = 4.0;

input group "=== 3b) Volatility / Spike Filter (EntryTF) ==="
input bool UseSpikeFilter = true;
input double MaxPrevBarRange_Price = 10.0;

input group "=== 4) Stops/Targets (Price Units) ==="
input double SL_Price = 4.0;
input double TP_Price = 6.0;

input group "=== 4a) ATR-based Stops/Targets (recommended) ==="
input bool   UseATRStops = true;
input double SL_ATR_Mult = 1.0;
input double TP_ATR_Mult = 1.5;
input double SL_Min_Price = 3.0;
input double SL_Max_Price = 8.0;
input double TP_Min_Price = 4.0;
input double TP_Max_Price = 18.0;

input group "=== 4b) Profit Lock (dynamic) ==="
input bool   UseProfitLock = true;
input double ProfitLock_MinTrigger_Price = 3.5;
input double ProfitLock_MinLockIn_Price  = 1.0;
input bool   UseDynamicLock = true;
input double DynamicLock_Fraction = 0.40;
input double DynamicLock_StartProfit_Price = 3.5;
input int    ProfitLock_MinImprovePoints = 35;
input double DynamicLock_MaxBelowTP_Price = 0.5;

input group "=== 4b2) ATR-linked Lock/BE (clamped) ==="
input bool   UseATRForManagementThresholds = true;
input double LockTrigger_ATR_Mult = 0.70;
input double LockTrigger_Min_Price = 3.5;
input double LockTrigger_Max_Price = 6.0;

input double LockIn_ATR_Mult = 0.20;
input double LockIn_Min_Price = 0.6;
input double LockIn_Max_Price = 1.5;

input double BETrigger_ATR_Mult = 0.80;
input double BETrigger_Min_Price = 3.5;
input double BETrigger_Max_Price = 7.0;

input bool   UseATRForDynamicStart = true;
input double DynamicStart_ATR_Mult = 0.50;
input double DynamicStart_Min_Price = 4.5;
input double DynamicStart_Max_Price = 6.0;

input group "=== 4c) Break-even (delayed) ==="
input bool   UseBreakEven = true;
input double BE_Trigger_Price = 3.5;
input int    BE_BufferPoints = 30;

input group "=== 5) Time Stop (stuck-loser cutter) ==="
input bool UseTimeStop = true;
input int  TimeStopMinutes = 90;
input double TimeStopMinProfit_Price = 0.0;
input bool TimeStop_OnlyIfNotLocked = true;
input bool TimeStop_OnlyIfLosing = true;

input bool UseATRForTimeStopMinProfit = false;
input double TimeStopMinProfit_ATR_Mult = 0.0;
input double TimeStopMinProfit_Min_Price = 0.0;
input double TimeStopMinProfit_Max_Price = 0.0;

input group "=== 6) Daily Stop (Loss Count) ==="
input int MaxLosingTradesPerDay = 2;

input group "=== 6b) Daily Stop (Equity % Drawdown) ==="
input bool   UseDailyEquityStop = true;
input double MaxDailyEquityDrawdownPct = 3.0;
input bool   ManagePositionsWhileDailyLocked = true;
input bool   UseDailyEquityStopDiagLog = true;
input double DailyEquityDiag_LogFromDdPct = 0.30;
input int    DailyEquityDiag_MinLogIntervalMin = 30;

input group "=== 6c) Risk rules for multiple positions ==="
input bool   RequireLockBefore2ndPos = true;
input double MinLockedProfitFor2ndPos_Price = 1.5;

input group "=== 7) Execution / Cost Filters ==="
input int MaxSpreadPoints = 22;
input bool UseRolloverFilter = true;
input int RolloverStartHour = 23;
input int RolloverStartMin  = 55;
input int RolloverEndHour   = 0;
input int RolloverEndMin    = 10;

input group "=== 7a) Spread-to-SL ratio filter ==="
input bool   UseSpreadRatioFilter = true;
input double MaxSpreadToSL_Ratio = 0.06;

input group "=== 7b) Cooldown / Re-entry ==="
input int CooldownBarsAfterClose = 2;
input bool NoReentrySameBar = true;

input group "=== 7d) Anti-revenge ==="
input bool UseAntiRevengeDirection = true;

input group "=== 7e) Session Filter (server time) ==="
input bool UseSessionFilter = true;
input int  SessionStartHour = 14;
input int  SessionEndHour   = 21;
input bool SessionAllowWrapMidnight = false;

input group "=== 7f) Auto Symbol Trade Sessions (soft fallback) ==="
input bool UseAutoSymbolTradeSessions = true;
input int  AutoSession_PreCloseBufferMin = 10;
input int  AutoSession_PostOpenBufferMin = 5;
input bool AutoSession_FallbackToManual = true;
input int AutoGap_MinGapMin = 3;
input int AutoGap_MaxGapMin = 360;

input group "=== 8) Portfolio target pause (auto base) ==="
input bool   UsePortfolioTargetPause = true;
input double TargetMultiple = 1.50;
input double ResumeMultiple = 1.02;
input bool   PauseNewEntriesOnTarget = true;
input bool   ManagePositionsWhilePaused = true;

input group "=== 9) Push Notifications ==="
input bool UsePushNotifications = true;

input group "=== 10) Reporting ==="
input bool DebugLog = true;
input bool PrintSummaryOnDeinit = true;
input double SmallWinThreshold = 1.0;

//======================== Globals ========================
int hTrendFast=INVALID_HANDLE, hTrendSlow=INVALID_HANDLE;
int hEntryEma=INVALID_HANDLE, hEntryRsi=INVALID_HANDLE;
int hATR=INVALID_HANDLE;

datetime g_testStartTime=0;
int g_magic=0;
double g_baseBalance=0.0;

bool g_lockToday=false;
int  g_losingToday=0;
bool g_buyBlockedToday=false;
bool g_sellBlockedToday=false;
int  g_dayStamp=0;

// daily equity stop
double g_dayStartEquity=0.0;
bool   g_dailyEquityLocked=false;
int    g_dailyEquityLocks=0;
datetime g_lastDailyEquityDiagLog=0;

datetime g_lastCloseTime=0;

// v29.5.4 fix: attempt bar
datetime g_lastEntryAttemptBar=0;

bool g_portfolioPause=false;
int  g_portfolioSignals=0;

// trade stats
int g_tradesOpened=0;
int g_addOnOpened=0;

// management stats
int g_profitLockMinSets=0;
int g_profitLockDynSets=0;
int g_beSets=0;
int g_timeStops=0;
int g_dailyLocks=0;

// skip stats
int g_skipSpreadPts=0;
int g_skipSpreadRatio=0;
int g_skipSession=0;
int g_skipRollover=0;
int g_skipPortfolioPause=0;

int g_skipATR=0;
int g_skipATR_Low=0;
int g_skipATR_High=0;
int g_skipATR_TooHighToTrade=0;

int g_halfLotByATR=0;

// auto session/gap skip
int g_skipAutoSession=0;
int g_skipAutoSessionPreClose=0;
int g_skipAutoSessionPostOpen=0;
int g_skipAutoSessionUnavailable=0;
int g_skipAutoGap=0;

// cached sessions
int g_sessionCacheStamp=0;
bool g_hasTradeSessionsToday=false;
int g_tradeSessCountToday=0;
int g_tradeSessOpenMin[10];
int g_tradeSessCloseMin[10];
int g_tradeGapStartMin=-1;
int g_tradeGapEndMin=-1;
bool g_hasTradeGapToday=false;

//==== Position state for management ====
struct PosState { long posId; datetime openTime; bool minLockDone; bool beDone; datetime lastMod; };
PosState g_pos[2200];
int g_posN=0;

//==== report aggregation ====
struct PosAgg { long posId; bool hasIn; bool hasOut; double profit; double profitOut; int deals; };
PosAgg g_agg[5000];
int g_aggN=0;

int g_closedTrades=0;
int g_closedDeals=0;
int g_wins=0;
int g_losses=0;
int g_smallWins=0;
int g_realWins=0;
double g_netProfit=0.0;

//======================== Helpers ======================
void Log(string m){ if(DebugLog) Print("[v29.5.4][",_Symbol,"] file=",__FILE__," ",m); }
void Notify(string m){ if(UsePushNotifications) SendNotification(m); }

string SU(string s){ StringToUpper(s); return s; }
bool IsAllowedSymbol()
{
   string sym=SU(_Symbol);
   string list=AllowedSymbols; StringToUpper(list);
   return (StringFind(","+list+",", ","+sym+",")>=0);
}
double Buf(int h,int bi,int sh){ double a[1]; if(CopyBuffer(h,bi,sh,1,a)<1) return 0.0; return a[0]; }
double Clamp(double v,double lo,double hi){ if(v<lo) return lo; if(v>hi) return hi; return v; }

double SpreadPrice()
{
   double a=SymbolInfoDouble(_Symbol,SYMBOL_ASK), b=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   if(a<=0||b<=0) return 999999.0;
   return (a-b);
}
int SpreadPoints(){ return (int)MathRound(SpreadPrice()/_Point); }

datetime NowServer(){ datetime ts=TimeTradeServer(); if(ts>0) return ts; return TimeCurrent(); }
int NowMinOfDay(){ MqlDateTime dt; TimeToStruct(NowServer(), dt); return dt.hour*60 + dt.min; }

int DayStampFromD1()
{
   datetime t=iTime(_Symbol, PERIOD_D1, 0);
   if(t<=0) t=TimeCurrent();
   MqlDateTime dt; TimeToStruct(t, dt);
   return dt.year*10000 + dt.mon*100 + dt.day;
}

void DailyResetIfNeeded()
{
   int s=DayStampFromD1();
   if(g_dayStamp==0 || s!=g_dayStamp)
   {
      g_dayStamp=s;
      g_lockToday=false;
      g_losingToday=0;
      g_buyBlockedToday=false;
      g_sellBlockedToday=false;

      g_dailyEquityLocked=false;
      g_dayStartEquity=AccountInfoDouble(ACCOUNT_EQUITY);
      if(g_dayStartEquity<=0) g_dayStartEquity=AccountInfoDouble(ACCOUNT_BALANCE);
      if(g_dayStartEquity<=0) g_dayStartEquity=1000.0;
      g_lastDailyEquityDiagLog=0;

      // reset cached sessions
      g_sessionCacheStamp=0;
      g_hasTradeSessionsToday=false;
      g_tradeSessCountToday=0;
      g_hasTradeGapToday=false;
      g_tradeGapStartMin=-1;
      g_tradeGapEndMin=-1;

      // reset attempt-bar
      g_lastEntryAttemptBar=0;

      Log("Daily reset stamp="+IntegerToString(g_dayStamp)+" dayStartEquity="+DoubleToString(g_dayStartEquity,2));
   }
}

// daily equity stop
double GetDailyDdPct()
{
   if(g_dayStartEquity<=0) return 0.0;
   double eq=AccountInfoDouble(ACCOUNT_EQUITY);
   if(eq<=0) return 0.0;
   return (g_dayStartEquity - eq) / g_dayStartEquity * 100.0;
}
void DailyEquityDiagLogMaybe(const double ddPct)
{
   if(!UseDailyEquityStopDiagLog) return;
   if(ddPct < DailyEquityDiag_LogFromDdPct) return;

   datetime now=TimeCurrent();
   int minSec = DailyEquityDiag_MinLogIntervalMin * 60;
   if(g_lastDailyEquityDiagLog!=0 && (now - g_lastDailyEquityDiagLog) < minSec) return;

   g_lastDailyEquityDiagLog = now;
   double eq=AccountInfoDouble(ACCOUNT_EQUITY);
   Log("Daily equity DD diag: ddPct="+DoubleToString(ddPct,2)+"% eq="+DoubleToString(eq,2)+
       " dayStartEq="+DoubleToString(g_dayStartEquity,2));
}
void CheckDailyEquityStop()
{
   if(!UseDailyEquityStop) return;
   if(g_dayStartEquity<=0) return;
   if(g_dailyEquityLocked) return;

   double ddPct = GetDailyDdPct();
   DailyEquityDiagLogMaybe(ddPct);

   if(ddPct >= MaxDailyEquityDrawdownPct)
   {
      g_dailyEquityLocked=true;
      g_dailyEquityLocks++;
      Log("Daily EQUITY LOCK: ddPct="+DoubleToString(ddPct,2)+"% >= "+DoubleToString(MaxDailyEquityDrawdownPct,2)+"%");
      Notify("v29.5.4 "+_Symbol+" DAILY EQUITY LOCK dd="+DoubleToString(ddPct,2)+"%");
   }
}

int ComputeRunMagic(){ int salt=(int)(g_testStartTime % 10000); int mix=(salt*97)%10000; return MagicBase*100 + mix; }
void InitMagic()
{
   g_magic = UseAutoMagic ? ComputeRunMagic() : MagicBase;
   trade.SetExpertMagicNumber(g_magic);
}

double EffectiveSLPrice(const double atr){ double sl=SL_Price; if(UseATRStops && atr>0.0) sl=atr*SL_ATR_Mult; return Clamp(sl, SL_Min_Price, SL_Max_Price); }
double EffectiveTPPrice(const double atr){ double tp=TP_Price; if(UseATRStops && atr>0.0) tp=atr*TP_ATR_Mult; return Clamp(tp, TP_Min_Price, TP_Max_Price); }

// Lot schedule
double TierLotByEquity(const double eq)
{
   double lot=Tier1_Lot;
   if(eq>=Tier1_EqMin && eq<=Tier1_EqMax) lot=Tier1_Lot;
   else if(eq>=Tier2_EqMin && eq<=Tier2_EqMax) lot=Tier2_Lot;
   else if(eq>=Tier3_EqMin && eq<=Tier3_EqMax) lot=Tier3_Lot;
   else if(eq>=Tier4_EqMin && eq<=Tier4_EqMax) lot=Tier4_Lot;
   else if(eq>=Tier5_EqMin && eq<=Tier5_EqMax) lot=Tier5_Lot;
   else if(eq>=Tier6_EqMin && eq<=Tier6_EqMax) lot=Tier6_Lot;

   double symbolMin=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double symbolMax=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   double symbolStep=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);

   double minLot=(MinLotOverride>0.0?MinLotOverride:symbolMin);
   if(minLot<=0) minLot=0.01;

   lot = Clamp(lot, minLot, MaxLot);
   if(symbolMax>0) lot=MathMin(lot, symbolMax);
   if(symbolStep>0) lot = MathFloor(lot/symbolStep)*symbolStep;
   lot = NormalizeDouble(lot, 2);
   return lot;
}
double ComputeLotFromBase()
{
   double symbolMin=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double symbolMax=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   double symbolStep=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);

   double minLot=(MinLotOverride>0.0?MinLotOverride:symbolMin);
   if(minLot<=0) minLot=0.01;

   int steps=(int)MathFloor(g_baseBalance/1000.0 + 1e-9);
   if(steps<1) steps=1;

   double lot = steps * LotPer1000;
   lot = Clamp(lot, minLot, MaxLot);
   if(symbolMax>0) lot = MathMin(lot, symbolMax);
   if(symbolStep>0) lot = MathFloor(lot/symbolStep)*symbolStep;
   lot = NormalizeDouble(lot, 2);
   return lot;
}
double ActiveLot(const double equityNow){ if(UseEquityTierLot) return TierLotByEquity(equityNow); return UseStepLot ? ComputeLotFromBase() : FixedLot; }

// ATR tier
int ATRTier(double atr)
{
   if(!UseATRFilter) return 1;
   if(atr<=0.0) return 1;
   if(ATR_Min_Price>0.0 && atr<ATR_Min_Price) return 0;
   if(ATR_MaxForTrading_Price>0.0 && atr>ATR_MaxForTrading_Price) return 3;
   if(ATR_MaxForAddOn_Price>0.0 && atr>ATR_MaxForAddOn_Price) return 2;
   return 1;
}
double TieredLot(const int tier, const double lot)
{
   if(tier==2) { g_halfLotByATR++; return NormalizeDouble(lot*ATR_HighLotFactor,2); }
   return lot;
}

// Entry logic
int TrendDir()
{
   double f=Buf(hTrendFast,0,1);
   double s=Buf(hTrendSlow,0,1);
   if(f==0||s==0) return 0;
   if(MathAbs(f-s) < MinTrendEMADistance_Price) return 0;
   if(f>s) return 1;
   if(f<s) return -1;
   return 0;
}
bool SpikeOk()
{
   if(!UseSpikeFilter) return true;
   double h=iHigh(_Symbol,EntryTF,1);
   double l=iLow(_Symbol,EntryTF,1);
   if(h==0||l==0) return true;
   return ((h-l) <= MaxPrevBarRange_Price);
}
bool EntrySignal(int dir)
{
   if(!SpikeOk()) return false;

   double ema=Buf(hEntryEma,0,1);
   double rsi=Buf(hEntryRsi,0,1);
   if(ema==0||rsi==0) return false;

   double close1=iClose(_Symbol,EntryTF,1);
   double close2=iClose(_Symbol,EntryTF,2);

   if(MathAbs(close1-ema) > MaxDistanceFromEntryEMA_Price) return false;

   if(dir==1)
   {
      if(!(rsi>=RSI_Buy_Min && rsi<=RSI_Buy_Max)) return false;
      if(close1<=close2) return false;
      return true;
   }
   if(dir==-1)
   {
      if(!(rsi>=RSI_Sell_Min && rsi<=RSI_Sell_Max)) return false;
      if(close1>=close2) return false;
      return true;
   }
   return false;
}

int CountMyPositions()
{
   int c=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong t=PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC)!=g_magic) continue;
      c++;
   }
   return c;
}

//======================== Auto Sessions (stable) ======================
struct Sess { int o; int c; };
void SortSessions(Sess &arr[], int n)
{
   for(int i=0;i<n-1;i++)
      for(int j=0;j<n-1-i;j++)
         if(arr[j].o > arr[j+1].o)
         {
            Sess t=arr[j]; arr[j]=arr[j+1]; arr[j+1]=t;
         }
}
bool LoadTodayTradeSessions()
{
   int stamp = DayStampFromD1();
   if(g_sessionCacheStamp==stamp) return g_hasTradeSessionsToday;

   g_sessionCacheStamp=stamp;
   g_hasTradeSessionsToday=false;
   g_tradeSessCountToday=0;
   g_hasTradeGapToday=false;
   g_tradeGapStartMin=-1;
   g_tradeGapEndMin=-1;

   MqlDateTime nowDT; TimeToStruct(NowServer(), nowDT);
   int dow = nowDT.day_of_week;

   Sess tmp[10];
   int n=0;

   for(int si=0; si<10; si++)
   {
      datetime from=0, to=0;
      if(!SymbolInfoSessionTrade(_Symbol, (ENUM_DAY_OF_WEEK)dow, si, from, to))
         break;
      if(from==0 && to==0) continue;

      MqlDateTime fdt, tdt;
      TimeToStruct(from, fdt);
      TimeToStruct(to, tdt);

      int o = fdt.hour*60 + fdt.min;
      int c = tdt.hour*60 + tdt.min;

      if(c==0 && o>0) c = 1440;
      if(o==c) continue;
      if(o<0||o>1440||c<0||c>1440) continue;

      tmp[n].o=o; tmp[n].c=c;
      n++; if(n>=10) break;
   }

   if(n<=0) return false;

   SortSessions(tmp, n);

   g_tradeSessCountToday=n;
   for(int i=0;i<n;i++){ g_tradeSessOpenMin[i]=tmp[i].o; g_tradeSessCloseMin[i]=tmp[i].c; }
   g_hasTradeSessionsToday=true;

   int bestGap=-1, bestSt=-1, bestEn=-1;
   for(int i=0;i<n-1;i++)
   {
      int gap = tmp[i+1].o - tmp[i].c;
      if(gap > bestGap){ bestGap=gap; bestSt=tmp[i].c; bestEn=tmp[i+1].o; }
   }
   int overnightGap = (1440 - tmp[n-1].c) + tmp[0].o;
   if(overnightGap > bestGap){ bestGap=overnightGap; bestSt=tmp[n-1].c; bestEn=tmp[0].o; }

   if(bestGap >= AutoGap_MinGapMin && bestGap <= AutoGap_MaxGapMin)
   {
      g_hasTradeGapToday=true;
      g_tradeGapStartMin=bestSt;
      g_tradeGapEndMin=bestEn;
   }

   return true;
}
bool InAnyTradeSessionNow(int nowMin)
{
   if(!g_hasTradeSessionsToday) return false;
   for(int i=0;i<g_tradeSessCountToday;i++)
   {
      int o=g_tradeSessOpenMin[i], c=g_tradeSessCloseMin[i];
      if(o<c) { if(nowMin>=o && nowMin<c) return true; }
      else    { if(nowMin>=o || nowMin<c) return true; }
   }
   return false;
}
int MinutesUntilCurrentSessionClose(int nowMin)
{
   if(!g_hasTradeSessionsToday) return -1;
   int best=999999; bool found=false;
   for(int i=0;i<g_tradeSessCountToday;i++)
   {
      int o=g_tradeSessOpenMin[i], c=g_tradeSessCloseMin[i];
      bool in = (o<c) ? (nowMin>=o && nowMin<c) : (nowMin>=o || nowMin<c);
      if(!in) continue;
      int mins = (o<c) ? (c-nowMin) : ((nowMin>=o)?(1440-nowMin+c):(c-nowMin));
      if(mins < best) best=mins;
      found=true;
   }
   return found?best:-1;
}
int MinutesSinceCurrentSessionOpen(int nowMin)
{
   if(!g_hasTradeSessionsToday) return -1;
   int best=999999; bool found=false;
   for(int i=0;i<g_tradeSessCountToday;i++)
   {
      int o=g_tradeSessOpenMin[i], c=g_tradeSessCloseMin[i];
      bool in = (o<c) ? (nowMin>=o && nowMin<c) : (nowMin>=o || nowMin<c);
      if(!in) continue;
      int mins = (o<c) ? (nowMin-o) : ((nowMin>=o)?(nowMin-o):(1440-o+nowMin));
      if(mins < best) best=mins;
      found=true;
   }
   return found?best:-1;
}
bool InAutoSessionGapWindow(int nowMin)
{
   if(!g_hasTradeGapToday) return false;
   int st=g_tradeGapStartMin, en=g_tradeGapEndMin;
   if(st<en) return (nowMin>=st && nowMin<en);
   return (nowMin>=st || nowMin<en);
}
bool InRolloverWindow()
{
   if(!UseRolloverFilter) return false;
   MqlDateTime dt; TimeToStruct(NowServer(), dt);
   int nowM=dt.hour*60 + dt.min;
   int stM=RolloverStartHour*60 + RolloverStartMin;
   int enM=RolloverEndHour*60 + RolloverEndMin;
   if(stM < enM) return (nowM>=stM && nowM<=enM);
   return (nowM>=stM || nowM<=enM);
}
bool InSession()
{
   if(!UseSessionFilter) return true;
   MqlDateTime dt; TimeToStruct(NowServer(), dt);
   int nowH=dt.hour;
   if(SessionStartHour==SessionEndHour) return true;
   if(SessionStartHour < SessionEndHour) return (nowH>=SessionStartHour && nowH<SessionEndHour);
   if(!SessionAllowWrapMidnight) return false;
   return (nowH>=SessionStartHour || nowH<SessionEndHour);
}
bool AllowNewEntriesBySessionAndRollover()
{
   if(UseAutoSymbolTradeSessions)
   {
      bool okLoaded = LoadTodayTradeSessions();
      int nowMin = NowMinOfDay();

      if(okLoaded && g_hasTradeSessionsToday)
      {
         if(!InAnyTradeSessionNow(nowMin)) { g_skipAutoSession++; return false; }

         int sinceOpen=MinutesSinceCurrentSessionOpen(nowMin);
         if(sinceOpen>=0 && sinceOpen < AutoSession_PostOpenBufferMin)
         {
            g_skipAutoSession++; g_skipAutoSessionPostOpen++; return false;
         }

         int toClose=MinutesUntilCurrentSessionClose(nowMin);
         if(toClose>=0 && toClose <= AutoSession_PreCloseBufferMin)
         {
            g_skipAutoSession++; g_skipAutoSessionPreClose++; return false;
         }

         if(UseRolloverFilter && InAutoSessionGapWindow(nowMin))
         {
            g_skipRollover++; g_skipAutoGap++; return false;
         }
         return true;
      }

      g_skipAutoSessionUnavailable++;
      if(!AutoSession_FallbackToManual) { g_skipAutoSession++; return false; }
   }

   if(!InSession()) { g_skipSession++; return false; }
   if(InRolloverWindow()) { g_skipRollover++; return false; }
   return true;
}

// Cost gate
bool CostGate(bool &failPts, bool &failRatio, const double effectiveSL)
{
   failPts=false; failRatio=false;
   int spPts = SpreadPoints();
   double spPrice = SpreadPrice();
   if(spPts > MaxSpreadPoints) failPts=true;

   if(UseSpreadRatioFilter)
   {
      double denom = (effectiveSL>0.0?effectiveSL:SL_Price);
      if(denom<=0.0) denom=1.0;
      if(spPrice > (denom*MaxSpreadToSL_Ratio)) failRatio=true;
   }
   return (!failPts && !failRatio);
}

bool CooldownActive()
{
   if(CooldownBarsAfterClose<=0) return false;
   if(g_lastCloseTime==0) return false;
   int tfSec=PeriodSeconds(EntryTF); if(tfSec<=0) tfSec=900;
   return (TimeCurrent() - g_lastCloseTime) < (CooldownBarsAfterClose * tfSec);
}

void CheckPortfolioTarget()
{
   if(!UsePortfolioTargetPause) return;
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   double targetEq = g_baseBalance * TargetMultiple;
   double resumeEq = g_baseBalance * ResumeMultiple;

   if(!g_portfolioPause && eq >= targetEq)
   {
      g_portfolioPause=true;
      g_portfolioSignals++;
      double suggestWithdraw = eq - resumeEq; if(suggestWithdraw < 0) suggestWithdraw = 0;
      Log("PORTFOLIO_TARGET_REACHED: equity="+DoubleToString(eq,2)+" -> PAUSE_NEW_ENTRIES");
      Notify("v29.5.4 "+_Symbol+" TARGET eq="+DoubleToString(eq,0)+" pause. Withdraw~"+DoubleToString(suggestWithdraw,0));
   }

   if(g_portfolioPause && eq <= resumeEq)
   {
      g_portfolioPause=false;
      Log("PORTFOLIO_RESUME: equity="+DoubleToString(eq,2)+" -> resume entries");
      Notify("v29.5.4 "+_Symbol+" RESUME eq="+DoubleToString(eq,0));
   }
}

// Management thresholds
double EffectiveLockTrigger(const double atr)
{
   double v=ProfitLock_MinTrigger_Price;
   if(UseATRForManagementThresholds && atr>0.0)
      v = Clamp(atr*LockTrigger_ATR_Mult, LockTrigger_Min_Price, LockTrigger_Max_Price);
   return v;
}
double EffectiveLockIn(const double atr)
{
   double v=ProfitLock_MinLockIn_Price;
   if(UseATRForManagementThresholds && atr>0.0)
      v = Clamp(atr*LockIn_ATR_Mult, LockIn_Min_Price, LockIn_Max_Price);
   return v;
}
double EffectiveBETrigger(const double atr)
{
   double v=BE_Trigger_Price;
   if(UseATRForManagementThresholds && atr>0.0)
      v = Clamp(atr*BETrigger_ATR_Mult, BETrigger_Min_Price, BETrigger_Max_Price);
   return v;
}
double EffectiveDynamicStart(const double atr)
{
   double v=DynamicLock_StartProfit_Price;
   if(UseATRForDynamicStart && atr>0.0)
      v = Clamp(atr*DynamicStart_ATR_Mult, DynamicStart_Min_Price, DynamicStart_Max_Price);
   return v;
}
double EffectiveTimeStopMinProfit(const double atr)
{
   double v=TimeStopMinProfit_Price;
   if(UseATRForTimeStopMinProfit && atr>0.0)
      v = Clamp(atr*TimeStopMinProfit_ATR_Mult, TimeStopMinProfit_Min_Price, TimeStopMinProfit_Max_Price);
   return v;
}
bool IsLockedInProfitSL(const bool isBuy, const double open, const double sl)
{
   if(sl<=0.0) return false;
   if(isBuy) return (sl > open);
   return (sl < open);
}

//======================== Trading: OpenTrade (RESTORED) ======================
bool OpenTrade(int dir, double lot, string tag, double atrForStops)
{
   if(dir==1 && UseAntiRevengeDirection && g_buyBlockedToday) return false;
   if(dir==-1 && UseAntiRevengeDirection && g_sellBlockedToday) return false;

   double symbolMin=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   if(symbolMin>0 && lot < symbolMin) return false;

   double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   if(ask<=0||bid<=0) return false;

   double slDist = EffectiveSLPrice(atrForStops);
   double tpDist = EffectiveTPPrice(atrForStops);

   double price=(dir==1)?ask:bid;
   double sl=(dir==1)? price-slDist : price+slDist;
   double tp=(dir==1)? price+tpDist : price-tpDist;
   sl=NormalizeDouble(sl,_Digits);
   tp=NormalizeDouble(tp,_Digits);

   trade.SetExpertMagicNumber(g_magic);
   bool ok=(dir==1)? trade.Buy(lot,_Symbol,price,sl,tp,tag)
                   : trade.Sell(lot,_Symbol,price,sl,tp,tag);
   if(ok)
   {
      g_tradesOpened++;
      Notify("v29.5.4 "+_Symbol+" OPEN "+string(dir==1?"BUY":"SELL")+" lot="+DoubleToString(lot,2)+" "+tag+
             " SLd="+DoubleToString(slDist,2)+" TPd="+DoubleToString(tpDist,2));
   }
   return ok;
}

//======================== Position Management (RESTORED) ======================
int FindPosState(long posId){ for(int i=0;i<g_posN;i++) if(g_pos[i].posId==posId) return i; return -1; }
int EnsurePosState(long posId, datetime openTime)
{
   int idx=FindPosState(posId);
   if(idx>=0) return idx;
   if(g_posN>=2200) g_posN=0;
   g_pos[g_posN].posId=posId;
   g_pos[g_posN].openTime=openTime;
   g_pos[g_posN].minLockDone=false;
   g_pos[g_posN].beDone=false;
   g_pos[g_posN].lastMod=0;
   return g_posN++;
}
bool CanModify(int st){ return (g_pos[st].lastMod==0 || (TimeCurrent()-g_pos[st].lastMod)>=20); }
void MarkModified(int st){ g_pos[st].lastMod=TimeCurrent(); }

bool ImproveSL(ulong ticket, bool isBuy, double tp, double &slCurrent, double newSL, int st, int &counter)
{
   newSL = NormalizeDouble(newSL, _Digits);

   bool improve = isBuy ? (slCurrent==0.0 || newSL>slCurrent) : (slCurrent==0.0 || newSL<slCurrent);
   double diffPts = (slCurrent==0.0)?999999:(MathAbs(newSL-slCurrent)/_Point);
   if(slCurrent!=0.0 && diffPts < ProfitLock_MinImprovePoints) improve=false;

   if(improve && trade.PositionModify(ticket, newSL, tp))
   {
      slCurrent = newSL;
      counter++;
      MarkModified(st);
      return true;
   }
   return false;
}

void ManageOpenPositions(const double atrForMgmt)
{
   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   if(bid<=0||ask<=0) return;

   double lockTrig = EffectiveLockTrigger(atrForMgmt);
   double lockIn   = EffectiveLockIn(atrForMgmt);
   double beTrig   = EffectiveBETrigger(atrForMgmt);
   double tsMinP   = EffectiveTimeStopMinProfit(atrForMgmt);
   double dynStart = EffectiveDynamicStart(atrForMgmt);

   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong t=PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC)!=g_magic) continue;

      long posId=(long)PositionGetInteger(POSITION_IDENTIFIER);
      long type=PositionGetInteger(POSITION_TYPE);
      bool isBuy=(type==POSITION_TYPE_BUY);

      datetime openTime=(datetime)PositionGetInteger(POSITION_TIME);
      int st=EnsurePosState(posId, openTime);

      double open=PositionGetDouble(POSITION_PRICE_OPEN);
      double sl=PositionGetDouble(POSITION_SL);
      double tp=PositionGetDouble(POSITION_TP);

      double price=isBuy?bid:ask;
      double profitDist = isBuy ? (price-open) : (open-price);

      if(UseProfitLock && !g_pos[st].minLockDone && profitDist >= lockTrig)
      {
         if(CanModify(st))
         {
            double minSL = open + (isBuy ? lockIn : -lockIn);
            bool ok = ImproveSL(t, isBuy, tp, sl, minSL, st, g_profitLockMinSets);
            g_pos[st].minLockDone = ok || true;
         }
      }

      if(UseProfitLock && UseDynamicLock && profitDist >= dynStart)
      {
         if(CanModify(st))
         {
            double dynLockIn = profitDist * DynamicLock_Fraction;
            if(dynLockIn < lockIn) dynLockIn = lockIn;

            double tpDist = TP_Price;
            if(tp>0.0) tpDist = MathAbs(tp-open);

            double maxLockIn = tpDist - DynamicLock_MaxBelowTP_Price;
            if(maxLockIn > 0 && dynLockIn > maxLockIn)
               dynLockIn = maxLockIn;

            double dynSL = open + (isBuy ? dynLockIn : -dynLockIn);
            ImproveSL(t, isBuy, tp, sl, dynSL, st, g_profitLockDynSets);
         }
      }

      if(UseBreakEven && !g_pos[st].beDone && profitDist >= beTrig)
      {
         if(CanModify(st))
         {
            double be = open + (isBuy ? (BE_BufferPoints*_Point) : -(BE_BufferPoints*_Point));
            be=NormalizeDouble(be,_Digits);

            bool need = isBuy ? (sl==0.0 || sl<be) : (sl==0.0 || sl>be);
            if(need && trade.PositionModify(t, be, tp))
            {
               g_pos[st].beDone=true;
               g_beSets++;
               MarkModified(st);
            }
         }
      }

      if(UseTimeStop && TimeStopMinutes>0)
      {
         int aliveMin=(int)((NowServer()-g_pos[st].openTime)/60);
         if(aliveMin < TimeStopMinutes) continue;

         bool lockedByState = (g_pos[st].minLockDone || g_pos[st].beDone);
         bool lockedBySL    = IsLockedInProfitSL(isBuy, open, sl);
         bool locked = (lockedByState || lockedBySL);

         if(TimeStop_OnlyIfNotLocked && locked) continue;
         if(TimeStop_OnlyIfLosing && profitDist >= 0.0) continue;

         if(profitDist < tsMinP)
         {
            if(trade.PositionClose(t))
               g_timeStops++;
         }
      }
   }
}

bool IsAnyPositionLockedInProfitAtLeast(const double minLocked, int &posCountOut)
{
   posCountOut=0;
   bool ok=true;

   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong t=PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC)!=g_magic) continue;

      posCountOut++;

      long type=PositionGetInteger(POSITION_TYPE);
      bool isBuy=(type==POSITION_TYPE_BUY);

      double open=PositionGetDouble(POSITION_PRICE_OPEN);
      double sl=PositionGetDouble(POSITION_SL);

      double locked = 0.0;
      if(sl>0.0) locked = isBuy ? (sl-open) : (open-sl);

      if(locked < minLocked) ok=false;
   }
   return (posCountOut>0 && ok);
}

//======================== Trade transaction (RESTORED) ======================
void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result)
{
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD) return;
   if(trans.symbol != _Symbol) return;

   ulong deal=trans.deal;
   if(deal==0) return;

   if((int)HistoryDealGetInteger(deal, DEAL_MAGIC) != g_magic) return;

   long entry=(long)HistoryDealGetInteger(deal, DEAL_ENTRY);
   if(entry != DEAL_ENTRY_OUT) return;

   long dealType=(long)HistoryDealGetInteger(deal, DEAL_TYPE);
   if(!(dealType==DEAL_TYPE_BUY || dealType==DEAL_TYPE_SELL)) return;

   double p = HistoryDealGetDouble(deal, DEAL_PROFIT)
            + HistoryDealGetDouble(deal, DEAL_SWAP)
            + HistoryDealGetDouble(deal, DEAL_COMMISSION);

   g_lastCloseTime = TimeCurrent();

   if(p < 0.0)
   {
      g_losingToday++;
      if(MaxLosingTradesPerDay>0 && g_losingToday >= MaxLosingTradesPerDay && !g_lockToday)
      {
         g_lockToday=true;
         g_dailyLocks++;
         Log("Daily LOCK: losingToday="+IntegerToString(g_losingToday)+
             " MaxLosingTradesPerDay="+IntegerToString(MaxLosingTradesPerDay));
         Notify("v29.5.4 "+_Symbol+" DAILY LOCK after "+IntegerToString(g_losingToday)+" losses");
      }

      if(UseAntiRevengeDirection)
      {
         if(dealType==DEAL_TYPE_BUY) g_buyBlockedToday=true;
         if(dealType==DEAL_TYPE_SELL) g_sellBlockedToday=true;
      }
   }
}

//======================== Reporting ======================
int FindAgg(const long posId){ for(int i=0;i<g_aggN;i++) if(g_agg[i].posId==posId) return i; return -1; }
int EnsureAgg(const long posId)
{
   int idx=FindAgg(posId);
   if(idx>=0) return idx;
   if(g_aggN>=5000) g_aggN=0;
   g_agg[g_aggN].posId=posId;
   g_agg[g_aggN].hasIn=false;
   g_agg[g_aggN].hasOut=false;
   g_agg[g_aggN].profit=0.0;
   g_agg[g_aggN].profitOut=0.0;
   g_agg[g_aggN].deals=0;
   return g_aggN++;
}
void ResetComputedReport()
{
   g_closedTrades=0; g_closedDeals=0; g_wins=0; g_losses=0;
   g_smallWins=0; g_realWins=0; g_netProfit=0.0; g_aggN=0;
}
void ComputeReportFromHistory()
{
   ResetComputedReport();
   if(!HistorySelect(0, TimeCurrent())) return;

   int total=HistoryDealsTotal();
   for(int i=0;i<total;i++)
   {
      ulong d=HistoryDealGetTicket(i);
      if(d==0) continue;
      if(HistoryDealGetString(d,DEAL_SYMBOL)!=_Symbol) continue;
      if((int)HistoryDealGetInteger(d,DEAL_MAGIC)!=g_magic) continue;

      long dealType=(long)HistoryDealGetInteger(d, DEAL_TYPE);
      if(!(dealType==DEAL_TYPE_BUY || dealType==DEAL_TYPE_SELL)) continue;

      long posId=(long)HistoryDealGetInteger(d, DEAL_POSITION_ID);
      if(posId<=0) continue;

      long entry=(long)HistoryDealGetInteger(d, DEAL_ENTRY);
      if(entry!=DEAL_ENTRY_IN && entry!=DEAL_ENTRY_OUT) continue;

      double profit = HistoryDealGetDouble(d,DEAL_PROFIT)
                    + HistoryDealGetDouble(d,DEAL_SWAP)
                    + HistoryDealGetDouble(d,DEAL_COMMISSION);

      int a=EnsureAgg(posId);
      g_agg[a].profit += profit;
      g_agg[a].deals++;
      g_closedDeals++;

      if(entry==DEAL_ENTRY_IN) g_agg[a].hasIn=true;
      else { g_agg[a].hasOut=true; g_agg[a].profitOut += profit; }
   }

   for(int i=0;i<g_aggN;i++)
   {
      if(!(g_agg[i].hasIn && g_agg[i].hasOut)) continue;
      g_closedTrades++;
      double pOut = g_agg[i].profitOut;
      g_netProfit += g_agg[i].profit;
      if(pOut >= 0.0) g_wins++; else g_losses++;
      if(pOut >= 0.0)
      {
         if(pOut < SmallWinThreshold) g_smallWins++;
         else g_realWins++;
      }
   }
}

//======================== MT5 Events ======================
int OnInit()
{
   if(!IsAllowedSymbol()) return INIT_FAILED;

   g_testStartTime = TimeCurrent();
   InitMagic();

   g_baseBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(g_baseBalance <= 0) g_baseBalance = 1000.0;

   hTrendFast=iMA(_Symbol,TrendTF,TrendEMA_Fast,0,MODE_EMA,PRICE_CLOSE);
   hTrendSlow=iMA(_Symbol,TrendTF,TrendEMA_Slow,0,MODE_EMA,PRICE_CLOSE);
   hEntryEma=iMA(_Symbol,EntryTF,EntryEMA,0,MODE_EMA,PRICE_CLOSE);
   hEntryRsi=iRSI(_Symbol,EntryTF,RSI_Period,PRICE_CLOSE);
   if(UseATRFilter) hATR=iATR(_Symbol, ATR_TF, ATR_Period);

   if(hTrendFast==INVALID_HANDLE||hTrendSlow==INVALID_HANDLE||hEntryEma==INVALID_HANDLE||hEntryRsi==INVALID_HANDLE)
      return INIT_FAILED;

   Print("### RUNNING EA v29.5.4 FIXED ### file=", __FILE__, " magic=", g_magic, " symbol=", _Symbol);

   DailyResetIfNeeded();
   if(UseAutoSymbolTradeSessions) LoadTodayTradeSessions();
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(hTrendFast!=INVALID_HANDLE) IndicatorRelease(hTrendFast);
   if(hTrendSlow!=INVALID_HANDLE) IndicatorRelease(hTrendSlow);
   if(hEntryEma!=INVALID_HANDLE) IndicatorRelease(hEntryEma);
   if(hEntryRsi!=INVALID_HANDLE) IndicatorRelease(hEntryRsi);
   if(hATR!=INVALID_HANDLE) IndicatorRelease(hATR);

   if(!PrintSummaryOnDeinit) return;

   ComputeReportFromHistory();

   Print("========== SUMMARY v29.5.4 FIXED ==========");
   Print("### FINISHED EA v29.5.4 FIXED ### file=", __FILE__, " magic=", g_magic, " symbol=", _Symbol);
   Print("Magic=",g_magic," BaseBalance=",DoubleToString(g_baseBalance,2),
         " TradesOpened=",g_tradesOpened," AddOnOpened=",g_addOnOpened);
   Print("Daily equity locks=", g_dailyEquityLocks, " Daily loss-count locks=", g_dailyLocks);
   Print("ReportLike: ClosedTrades=",g_closedTrades," ClosedDeals=",g_closedDeals,
         " Wins=",g_wins," Losses=",g_losses," SmallWins=",g_smallWins," RealWins=",g_realWins);
   Print("ReportLike NetProfit=",DoubleToString(g_netProfit,2));
   Print("ProfitLockMinSets=",g_profitLockMinSets," ProfitLockDynSets=",g_profitLockDynSets,
         " BE_Sets=",g_beSets," TimeStops=",g_timeStops);
   Print("Skip: autoSess=",g_skipAutoSession," (preClose=",g_skipAutoSessionPreClose," postOpen=",g_skipAutoSessionPostOpen,
         " unavailable=",g_skipAutoSessionUnavailable,") autoGap=",g_skipAutoGap,
         " session=",g_skipSession," rollover=",g_skipRollover,
         " spreadPts=",g_skipSpreadPts," spreadRatio=",g_skipSpreadRatio," ATR=",g_skipATR,
         " portfolioPause=",g_skipPortfolioPause);
   Print("==================================");
}

void OnTick()
{
   DailyResetIfNeeded();
   CheckDailyEquityStop();
   CheckPortfolioTarget();

   double atr=0.0;
   if(UseATRFilter && hATR!=INVALID_HANDLE) atr = Buf(hATR, 0, 1);

   if(g_dailyEquityLocked)
   {
      if(ManagePositionsWhileDailyLocked)
         ManageOpenPositions(atr);
      return;
   }

   if(g_lockToday)
   {
      ManageOpenPositions(atr);
      return;
   }

   if(UsePortfolioTargetPause && PauseNewEntriesOnTarget && g_portfolioPause)
   {
      g_skipPortfolioPause++;
      if(ManagePositionsWhilePaused)
         ManageOpenPositions(atr);
      return;
   }

   if(!AllowNewEntriesBySessionAndRollover())
      return;

   double effSL = EffectiveSLPrice(atr);
   bool failPts=false, failRatio=false;
   if(!CostGate(failPts, failRatio, effSL))
   {
      if(failPts) g_skipSpreadPts++;
      if(failRatio) g_skipSpreadRatio++;
      return;
   }

   int tier = ATRTier(atr);
   if(tier==0) { g_skipATR++; g_skipATR_Low++; return; }
   if(tier==3) { g_skipATR++; g_skipATR_High++; g_skipATR_TooHighToTrade++; return; }

   ManageOpenPositions(atr);

   int posCount=CountMyPositions();
   if(posCount >= MaxOpenPositions) return;

   if(RequireLockBefore2ndPos && posCount>=1)
   {
      int pc=0;
      if(!IsAnyPositionLockedInProfitAtLeast(MinLockedProfitFor2ndPos_Price, pc))
         return;
   }

   if(CooldownActive()) return;

   datetime barTime=iTime(_Symbol,EntryTF,0);
   if(barTime==0) return;

   // FIX: block only if we already attempted an entry in this bar (after real signal)
   if(NoReentrySameBar && barTime==g_lastEntryAttemptBar)
      return;

   int tdir=TrendDir();
   if(tdir==0) return;

   if(!EntrySignal(tdir)) return;

   // mark attempt after we have a real signal (prevents blocking the whole bar)
   g_lastEntryAttemptBar = barTime;

   double eqNow = AccountInfoDouble(ACCOUNT_EQUITY);
   if(eqNow<=0) eqNow = AccountInfoDouble(ACCOUNT_BALANCE);

   double lot = ActiveLot(eqNow);
   lot = TieredLot(tier, lot);
   if(lot<=0) return;

   OpenTrade(tdir, lot, "v29.5.4", atr);
}