//+------------------------------------------------------------------+
//|                                   SAFE_MULTI_PAIR_BOT_MQL5.mq5   |
//+------------------------------------------------------------------+
#property strict
#include <Trade\Trade.mqh>

// Initialisation de la classe de trading MQL5
CTrade trade;

string Symbols[] = {"EURUSD","GBPUSD","USDJPY","USDCHF","AUDUSD","XAUUSD","BTCUSD","ETHUSD"};
double RiskPercent = 0.8;

//==============================
// SAFE MODE (DRAWDOWN)
//==============================
bool SafeMode()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double dd = (balance - equity) / balance * 100.0;

   if(dd > 5.0) {
      Print("STOP: DRAWDOWN LIMIT REACHED");
      return false;
   }
   return true;
}

//==============================
// SESSIONS (MQL5 WAY)
//==============================
bool IsTradingTime()
{
   MqlDateTime dt;
   TimeCurrent(dt);
   int h = dt.hour;
   return ((h >= 8 && h < 12) || (h >= 13 && h < 17));
}

//==============================
// LOT SIZE (SÉCURISÉ)
//==============================
double GetLotSize(string sym, double sl_points)
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = balance * RiskPercent / 100.0;
   double tickValue = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_VALUE);
   
   if(sl_points <= 0) return 0.01;
   
   double lot = riskAmount / (sl_points * tickValue);
   double minLot = SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN);
   return NormalizeDouble(MathMax(minLot, lot), 2);
}

//==============================
// TREND FILTER (EMA 50)
//==============================
bool TrendUp(string sym)
{
   double ema[];
   int handle = iMA(sym, PERIOD_H1, 50, 0, MODE_EMA, PRICE_CLOSE);
   ArraySetAsSeries(ema, true);
   if(CopyBuffer(handle, 0, 0, 1, ema) <= 0) return false;
   return (SymbolInfoDouble(sym, SYMBOL_LAST) > ema[0]);
}

bool TrendDown(string sym)
{
   double ema[];
   int handle = iMA(sym, PERIOD_H1, 50, 0, MODE_EMA, PRICE_CLOSE);
   ArraySetAsSeries(ema, true);
   if(CopyBuffer(handle, 0, 0, 1, ema) <= 0) return false;
   return (SymbolInfoDouble(sym, SYMBOL_LAST) < ema[0]);
}

//==============================
// POSITION CHECK
//==============================
bool HasPosition(string sym)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
      if(PositionGetSymbol(i) == sym) return true;
   return false;
}

//==============================
// EXECUTION DES TRADES
//==============================
void OpenBuy(string sym)
{
   double price = SymbolInfoDouble(sym, SYMBOL_ASK);
   double sl = iLow(sym, PERIOD_H1, 1);
   double tp = price + (price - sl) * 2.0;
   double sl_dist = (price - sl) / SymbolInfoDouble(sym, SYMBOL_POINT);
   
   trade.Buy(GetLotSize(sym, sl_dist), sym, price, sl, tp, "SAFE BUY");
}

void OpenSell(string sym)
{
   double price = SymbolInfoDouble(sym, SYMBOL_BID);
   double sl = iHigh(sym, PERIOD_H1, 1);
   double tp = price - (sl - price) * 2.0;
   double sl_dist = (sl - price) / SymbolInfoDouble(sym, SYMBOL_POINT);
   
   trade.Sell(GetLotSize(sym, sl_dist), sym, price, sl, tp, "SAFE SELL");
}

//==============================
// MAIN LOOP
//==============================
void OnTick()
{
   if(!SafeMode() || !IsTradingTime()) return;

   for(int i = 0; i < ArraySize(Symbols); i++)
   {
      string sym = Symbols[i];
      if(!SymbolSelect(sym, true) || HasPosition(sym)) continue;

      if(TrendUp(sym)) OpenBuy(sym);
      else if(TrendDown(sym)) OpenSell(sym);
   }
}
