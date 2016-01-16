//+------------------------------------------------------------------+
//| MACD and Break Line                                              +
//+------------------------------------------------------------------+
#property copyright   "2015 michael"
#property link        "http://www.mql4.com"
/*
半自动系统，用于Boller线趋势跟踪自动下单，用上下轨止盈止损。核心思想是只吃趋势的中段，放弃头尾。
M15，周期50 width 2
*/

//----
extern int    band = 20;
extern string BuyLimit_Trend_Info = "_______________________";
extern bool   BuyLimit_Enabled = true;
extern int    BuyLimit_TakeProfit = 500;
extern int    BuyLimit_StopLoss = 300;
extern double BuyLimit_Lot = 0.1;
extern int    BuyLimit_StepUpper = 300;
extern int    BuyLimit_StepLower = 50;

//------
int MagicBuyStop = 21101;
int MagicSellStop = 21102;
int MagicBuyLimit = 21103;
int MagicSellLimit = 21104;
int glbOrderType;
int glbOrderTicket;
//must be global to use continually
datetime     pt = 0;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick(void)
  {
   Comment("my1-2-3 v0.1");
//---
// initial data checks
// it is important to make sure that the expert works with a normal
// chart and the user did not make any mistakes setting external 
// variables (Lots, StopLoss, TakeProfit, 
// TrailingStop)
   RefreshRates();
   if(TimeCurrent() - Time[0] <  Period()*60 - 30) return;
   OpenTrade();
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OpenTrade()
  {
      double vH, vL, vM, sl, tp;
      //get signal
     {
       double bPrice = iBands(Symbol(),0,band,2,0,PRICE_CLOSE,MODE_MAIN,0);
       double buyHighPrice = bPrice + BuyLimit_StepUpper*Point;
       double buyLowPrice = bPrice - BuyLimit_StepLower*Point;
       vH = NormalizeDouble(buyHighPrice,Digits);
       vM = NormalizeDouble(bPrice,Digits);
       vL = NormalizeDouble(buyLowPrice,Digits);
       sl = vL - BuyLimit_StopLoss*Point;
       tp = vL + BuyLimit_TakeProfit*Point;
       if(Ask <= vH && Ask >= vM && OrderFind(MagicBuyLimit) == false)
           if(OrderSend(Symbol(), OP_BUYLIMIT, BuyLimit_Lot, vL, 3, sl, tp,
              "", MagicBuyLimit, 0, Green) < 0)
               Print("Err (", GetLastError(), ") Open BuyLimit Price= ", vL, " SL= ", 
                     sl," TP= ", tp, "lots=", BuyLimit_Lot);
       if(Ask <= vH && Ask >= vM && GetTotalOrdersA(MagicBuyLimit, OP_BUY) < totalOrders && 
          glbOrderType == OP_BUYLIMIT)
         {
           OrderSelect(glbOrderTicket, SELECT_BY_TICKET, MODE_TRADES);
           if(vH != OrderOpenPrice())
               if(OrderModify(glbOrderTicket, vL, sl, tp, 0, Green) == false)
                   Print("Err (", GetLastError(), ") Modify BuyLimit Price= ", vL, 
                         " SL= ", sl, " TP= ", tp);
         }
     }
 
   return(0);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool OrderFind(int Magic)
  {
   glbOrderType = -1;
   glbOrderTicket = -1;
   int total = OrdersTotal();
   bool res = false;
   for(int cnt = 0 ; cnt < total ; cnt++)
     {
       OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES);
       if(OrderMagicNumber() == Magic && OrderSymbol() == Symbol())
         {
           glbOrderType = OrderType();
           glbOrderTicket = OrderTicket();
           res = true;
         }
     }
   return(res);
  }
