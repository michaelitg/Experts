//+------------------------------------------------------------------+
//|                                                  MACD Sample.mq4 |
//|                      Copyright ?2005, MetaQuotes Software Corp. |
//|                                       http://www.metaquotes.net/ |
//+------------------------------------------------------------------+

#include <common.mqh>
extern int  MaxLots = 5;
extern double TakeProfit = 600;
extern double Lots = 1; //0.1
extern double StopLoss = 80;
extern int    PFast = 100;
extern int    PSlow = 200;
extern int    PSignal = 30;
extern int    peak_length  = 3;
extern int    peak_depth = 5;
extern int    PTrendEMAN = 5;
extern int    forceReverse = 300;
extern int    forceTrend = -1;
extern int    nofilter = 0;
extern double ReversePercent = 0;  //don't reverse for GER30 1H/M15
extern double AddPercent = 1.2; //Add Plan trade lots percent 0.2=>1.2
extern double AddRate = 0.2;   //Add Plan mark position 0.4=>0.1 0.6 is also better
extern double PlanRate = 0.05;  //Add Plan trade position 0.2 => 0, since GER30很少会再回测
extern double LimitRate = 0.2;  //Add Plan trade position up limit
extern string IndicatorName = "MACD";

extern string version= "6.2R";  //Release version
extern string comment1 = "manOrder=1:immediate buy/sell 2:immediate reverse trade 0: normal";
extern int    manOrder = 0;   //
extern string comment11 = "manOrderOp=0-Buy 1-Sell";
extern int    manOrderOp = 0;  //
extern int    manTrend = -1;   //

int timeOrder = 0;
datetime ptime = 0;
datetime ptime2 = 0;
datetime ptime3 = 0;
datetime ptime4 = 0;
datetime dp3 = 0;
datetime lasttime = 0;

#define MAGICMA  20131018
#define MAGICMB  20180522

double myATR(int t, int s, int p)
{
   int i;
   double c1, max, tmax;
   max = 0;
   tmax = 0;
   for( i = s; i <= p+s; i++)
   {
      max = iHigh(NULL, t, i) - iLow(NULL, t, i);
      c1 = MathAbs(iHigh(NULL, t, i) - iClose(NULL, t, i+1));
      if( max < c1) max = c1;
      c1 = MathAbs(iLow(NULL, t, i) - iClose(NULL, t, i+1));
      if( max < c1) max = c1;
      tmax += max;
   }
   return(tmax / p);
}

int start()
  {
   double lots, tk, sl, RevPercent;

   if( manOrder == 1)
   {
        int tt = GetOrder(MAGICMA, OP_SELL);
        if( tt == -1 )
            OpenOrder(manOrderOp, Lots, StopLoss, TakeProfit, MAGICMA, ReversePercent);
        manOrder = 0;
        return(0);
   }

   string comment;
   string ss[2];
   ss[0] = "buy";
   ss[1] = "sell";

   int t = GetOrder(MAGICMA, OP_SELL);
   if( t > 0 && AddRate > 0 && timeOrder != Hour()){ //add position
      timeOrder = Hour();
      ClosePendingOrder(MAGICMA);
      comment = "BollerTrade: add position ";
      AddOrder2(MAGICMA, LotsOptimized(AddPercent), AddRate, TakeProfit, PlanRate, LimitRate,comment,MaxLots);
   }

   {
      lots = Lots;
      tk = TakeProfit;
      sl = StopLoss;
      RevPercent = ReversePercent;
   }

   double updown = iCustom(NULL, 0, IndicatorName, PFast, PSlow, PSignal, peak_length, peak_depth, PTrendEMAN, forceReverse, forceTrend, nofilter, 2, 11);
   if(false) Print("----------------MACD=",updown,"@",TimeToStr(TimeCurrent()));
   int op = -1;
   if( updown == -1 || updown == -2) op = 1;
   else if( updown == 1 || updown == 2) op = 0;

   if( manOrder == 2){
      op = manOrderOp;
      manOrder = 0;
   }

   if( op != -1 )
   {
      if( forceTrend != -1)
      {
            int t1 = GetOrder(MAGICMB, OP_SELL);
            if( t1 == -1 && op == forceTrend)
            {
               comment = "BollerTrade:trend open"+ss[op]+" order"+"[original "+ss[OrderType()]+" order:"+t+"]";
               tk = StopLoss;
               sl = StopLoss;
               OpenOrder(op, lots, sl, tk, MAGICMB, RevPercent, comment);
            }
      }
      else{
          if( t == -1 ){
               comment = "BollerTrade:New "+ss[op]+" order";
               OpenOrder(op, lots, sl, tk, MAGICMA, RevPercent, comment);
         }
         else if( op != OrderType()){
               comment = "BollerTrade:reverse open"+ss[op]+" order"+"[original "+ss[OrderType()]+" order:"+t+"]";
               OpenReverseOrder(t, op, lots, sl, tk, MAGICMA, RevPercent,comment);
         }
      }
      /*纯粹使用信号开平仓，不使用加仓和反手系统，无论如何调整止盈和止损，都无法实现正盈利
      int tt = GetOrder(MAGICMA+40, OP_SELL);
      if( tt == -1 ) OpenShortOrder(op, ShortLots, ShortSL, ShortTK, MAGICMA+40);
      else CloseOrder(tt, op);
      */
      Sleep(60000);
   }
   //Print(TimeToStr(TimeCurrent(), TIME_DATE), skiptime1, StringFind(TimeToStr(TimeCurrent(), TIME_DATE), skiptime1));
   /*
      if( TimeCurrent() - ptime2 > 360)
      {
         ptime2 = TimeCurrent();
         Print("========xxxxxxxtrend=",trend,"op=",op,"atr=",iATR(NULL, 30, autoTrendPeriod, 0),"sum=",sum / autoTrendRange,"@",TimeToStr(ptime2));
      }
      */
   return(0);
  }
// the end.