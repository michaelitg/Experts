//+------------------------------------------------------------------+
//|                                                  MACD Sample.mq4 |
//|                      Copyright ?2005, MetaQuotes Software Corp. |
//|                                       http://www.metaquotes.net/ |
//+------------------------------------------------------------------+
#include <helpers.mqh>
#include <common.mqh>
extern bool Enable_MM1 = true;
extern bool Enable_MM3 = false;
extern int  MaxLots = 5;
extern int  tradeTime = 360;
//M15: GER30 800 sl 100 tk 300 start capital: 1500 from 2018-1-1 - 2018-12-17
//4550.03	43	3.35	105.81	1236.36	58.75%	0.00000000	TradeMAPeriod=800	Enable_MM1=1 	Enable_MM3=0 	MaxLots=5 	TakeProfit=300 	Lots=1 	StopLoss=100 	ReversePercent=0.1 	AddPercent=1.2 	AddRate=0.1 	PlanRate=0.1 	LimitRate=0.2 	manOrder=0 	manOrderOp=0 	CBarsFrac=26 	AddPercentMM3=0.1 	manTrend=-1 	autoTrendMethod=-1 	autoTrendRange=24 	autoTrendPeriod=12 	autoTrendLevel=2.2 	RunPeriod=15 	updownLevel=11 	updowncount=3 	shortma=7 	shortmashift=3
//M15: US30 start capital: 1500 from 2018-1-1 - 2018-12-18
//63603.10	130	2.91	489.25	12931.80	38.71%	0.00000000	TakeProfit=500 	StopLoss=160 	ReversePercent=0.2 	AddRate=0.1 	PlanRate=0	Enable_MM1=1 	Enable_MM3=0 	MaxLots=5 	TradeMAPeriod=800 	Lots=1 	AddPercent=1.2 	LimitRate=0.2 	manOrder=0 	manOrderOp=0 	CBarsFrac=26 	AddPercentMM3=0.1 	manTrend=-1 	autoTrendMethod=-1 	autoTrendRange=24 	autoTrendPeriod=12 	autoTrendLevel=2.2 	RunPeriod=15 	updownLevel=11 	updowncount=3 	shortma=7 	shortmashift=3
//good data:	63689.60	174	2.35	366.03	16188.00	64.16%	0.00000000	TradeMAPeriod=500 	TakeProfit=700 	StopLoss=300	Enable_MM1=1 	Enable_MM3=0 	MaxLots=5 	tradeTime=360 	Lots=1 	ReversePercent=0.2 	AddPercent=1.2 	AddRate=0.1 	PlanRate=0 	LimitRate=0.2 	manOrder=0 	manOrderOp=0 	CBarsFrac=26 	AddPercentMM3=0.1 	manTrend=-1 	autoTrendMethod=-1 	autoTrendRange=24 	autoTrendPeriod=12 	autoTrendLevel=2.2 	RunPeriod=15 	updownLevel=11 	updowncount=3 	shortma=7 	shortmashift=3
//add order mixed position start 2000:
//71087.60	187	2.33	380.15	17831.10	61.24%	0.00000000	TakeProfit=700 	StopLoss=200	Enable_MM1=1 	Enable_MM3=0 	MaxLots=5 	tradeTime=360 	TradeMAPeriod=500 	Lots=1 	ReversePercent=0.2 	AddPercent=1.2 	AddRate=0.1 	PlanRate=0 	LimitRate=0.2 	manOrder=0 	manOrderOp=0 	CBarsFrac=26 	AddPercentMM3=0.1 	manTrend=-1 	autoTrendMethod=-1 	autoTrendRange=24 	autoTrendPeriod=12 	autoTrendLevel=2.2 	RunPeriod=15 	updownLevel=11 	updowncount=3 	shortma=7 	shortmashift=3
extern int TradeMAPeriod = 500;
extern double TakeProfit = 700;
extern double Lots = 1; //0.1
extern double StopLoss = 200;
//extern double StopLossMM3 = 120;
extern double ReversePercent = 0.2;  //don't reverse for GER30 1H/M15
extern double AddPercent = 1.2; //Add Plan trade lots percent 0.2=>1.2
extern double AddRate = 0.1;   //Add Plan mark position 0.4=>0.1 0.6 is also better
extern double PlanRate = 0;  //Add Plan trade position 0.2 => 0, since GER30很少会再回测
extern double LimitRate = 0.2;  //Add Plan trade position up limit
extern string version= "6.07 US30";  //Release version - change to indicator signal
extern string comment1 = "manOrder=1:immediate buy/sell 2:immediate reverse trade 0: normal";
extern int    manOrder = 0;   //
extern string comment11 = "manOrderOp=0-Buy 1-Sell";
extern int    manOrderOp = 0;  //

extern int CBarsFrac    = 26;   //MM3
extern double AddPercentMM3 = 0.1; //Add Plan trade lots percent
extern string comment2 = "manTrend=-1: auto calculate 0: no trend 1: has trend";
extern int    manTrend = -1;   //

//extern int    noTrendTrade = 0;
//extern int    noTrendSignal = 0;
extern int    autoTrendMethod = -1;  //0 - iATR 1 - 006-myATR
extern int    autoTrendRange = 24;
extern int    autoTrendPeriod = 12;
extern double autoTrendLevel = 2.2;  //for sfa 2.00 fxcm 1.99 every platform should be different
extern int RunPeriod = 15;
extern double updownLevel = 11;
extern int    updowncount = 3;
extern int    shortma = 7;
extern int    shortmashift = 3;
extern int    cbars = 1;


string skiptime1 = ""; //"2013.12.06,2013.12.18";
datetime ptime = 0;
datetime ptime1 = 0;
datetime ptime3 = 0;
datetime ptime4 = 0;
datetime dp3 = 0;
datetime lasttime = 0;

#define MAGICMA  20131018
#define MAGICMB  20131019
#define MAGICMC  20131017

/*
bool isClose()
{
   if( OrderType() == OP_BUY) return(isDown(TradeMAPeriod/2));
   else return(isUp(TradeMAPeriod/2));
}
*/
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

/*
//ok, but already has loss proctect of new order position size
// ( if close a loss order, the new order position will be doubled)
//and limit the real trend
//and can cut the loss in some cases
//must select the order firstly
int getOrderK()
{
   datetime d = OrderOpenTime();
   int i;
   for( i = 0; i < Bars; i++)
   {
      if( Time[i] < d ) break;
   }
   //Print("i=",i,"time=",Time[i],"d=",d);
   return(i);
}
bool CheckTkOrder(int mag)
{
      int t = GetTotalOrders(mag, OP_SELL);
      if( t < 3) return(false);

     if( GetOrder(MAGICMA, OP_SELL) < 0) return;
     double pro = TakeProfit*8*Point;
     int k = getOrderK();
     if( k == 0) return(false);
     double p = OrderOpenPrice();
     bool isProfit = false;
     if( OrderType() == OP_BUY){
       double MaxH = High[iHighest(NULL,0,MODE_HIGH,k,0)];
       if( MaxH >= p+pro ) isProfit = true;
       //Print("k=",k,"Pro=",pro,"p=",p,"maxH=",MaxH);
     }
     else{
       double MaxL = Low[iLowest(NULL,0,MODE_LOW,k,0)];
       if( MaxL <= p - pro ) isProfit = true;
       //Print("k=",k,"Pro=",pro,"p=",p,"p-pro",p-pro,"maxL=",MaxL);
     }

     if( isProfit )
     {
           double sl = TakeProfit*7*Point;
           if( MathAbs(OrderOpenPrice() - Close[0]) < sl ) return(true);
     }
     return(false);
}

/*
void AddOrder3(int mag, double lots, double stairRate, int StopLoss, int TakeProfit, string c="")
  {
   int t = -1;
   int n = GetTotalOrders(mag, OP_SELL);
   for(int i=OrdersTotal()-1;i >= 0;i--)
     {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==false) break;
      if( (mag != 0 && OrderMagicNumber()!= mag) || OrderSymbol()!=Symbol()) continue;
      //---- check order type
      if( OrderType() <= OP_SELL){ t= OrderTicket(); break; }
     }
   if( t == -1) return;

   double tk = OrderTakeProfit();
   double sl;
   int sli = StopLoss / n;
   if( sli < 50) sli = 50;
   int ticket;
  double StairProfit = TakeProfit * stairRate;
  //if( n > 2 && OrderProfit() < (-StopLoss)/2) CloseOrder(t, 1-OrderType());
 //Print("t=",t,"StairProfit=",StairProfit,"n=",n,"pt=",OrderProfit(),"m=",(((1+n)*n)/2)*StairProfit);
 //if( n == 2) lots *= 2;
 if ( OrderProfit()>((((1+n)*n)/2)*StairProfit)){
   if (OrderType()==OP_BUY) {
         sl = Ask - sli * getPoint();
    //if ( OrderProfit()>(n*StairProfit)){
         Print("Add new buy order ",n+1, "at ",Ask);
         ticket=OrderSend(Symbol(),OP_BUY,lots,Ask,0,sl,tk,c+"Buy",mag,0,Green);
   }
   if (OrderType()==OP_SELL) {
         sl = Bid + sli * getPoint();
    //if ( OrderProfit()>(n*StairProfit)){
         Print("Add new sell order ",n+1, "at ",Bid);
         ticket=OrderSend(Symbol(),OP_SELL,lots,Bid,0,sl,tk,c+"Sell",mag,0,Red);
   }
 }

}


*/

int init()
{
   initLog();
   skiptime1 = xmlRead("skiptime.txt");
   return 0;
}

int start()
  {
   double lots, tk, sl, RevPercent;

   if( manOrder == 1)
   {
        int tt = GetOrder(MAGICMA, OP_SELL);
        if( tt == -1 )
            OpenOrder(manOrderOp, 0.1, StopLoss, TakeProfit, MAGICMA, ReversePercent);
        manOrder = 0;
        return(0);
   }
   //if( manOrder == 0) if( Period() != RunPeriod ) return;

   string comment, sss[2];
   sss[0] = "swing";
   sss[1] = "trend";
   string ss[2];
   ss[0] = "buy";
   ss[1] = "sell";

   if( Enable_MM1 )
   {
     /*
      if(CheckTkOrder(MAGICMA) == true)
      {
         Print("****************************123*********************");
         CloseOrder2(MAGICMA);
      }
      */
      ClosePendingOrder(MAGICMA);
      comment = "BollerTrade:"+sss[1]+" add position";
      AddOrder2(MAGICMA, LotsOptimized(AddPercent), AddRate, TakeProfit, PlanRate, LimitRate,comment,MaxLots);
   }

   if( Enable_MM3 )
   {
      ClosePendingOrder(MAGICMC);
      string comment3 = "BollerTradeMM3:add position";
      AddOrder2(MAGICMC, LotsOptimized(AddPercentMM3), AddRate, TakeProfit, PlanRate, LimitRate,comment3,MaxLots);
   }

   /* bad, no use
   for( int i = 0; i < autoTrendRange; i++)
      sum += iADX(NULL, period*2, 48, PRICE_CLOSE, 0, i);
   if( sum / autoTrendRange > 12) trend = 1;
   else trend = 0;
   */

   {
      lots = Lots;
      tk = TakeProfit;
      sl = StopLoss;
      RevPercent = ReversePercent;
      //有趋势才加仓
      //comment = "BollerTrade:"+sss[1]+"加仓";
      //if( StairRate > 0 && TrendHard() > 0)
         //AddOrder3(MAGICMA, LotsOptimized(AddPercent)/2, StairRate, StopLoss, TakeProfit, comment);
      //else
         //AddOrder2(MAGICMA, LotsOptimized(AddPercent), AddRate, TakeProfit, PlanRate, LimitRate,comment);
   }

   //log(2,StringConcatenate(TimeCurrent() - Time[0], "compare to ", Period()*60 - 360) );
   if( manOrder == 0) if(TimeCurrent() - Time[0] <  Period()*60 - tradeTime) return(0);

   //RefreshRates();
   //if( manOrder == 0) if(lasttime == Time[0]) return;
   //lasttime = Time[0];
   if( skiptime(MAGICMA, skiptime1)){
      skiptime(MAGICMB, skiptime1);
      skiptime(MAGICMC, skiptime1);
      return(0);
   }
   //if( CheckTkOrder() == true){ Print("&&&&&&&&&&&&&&&&close tk order!!!",OrderTicket());CloseOrder(OrderTicket(), 1-OrderType()); Sleep(100000); return;}
   //double p =  iMA(NULL,0,TradeMAPeriod,0,MODE_SMA,PRICE_CLOSE, 0);
   //cause loss delete if( CheckBigK(p, StopLoss, TakeProfit, MAGICMA, ReversePercent) ) return;
   //close the order according to mv
   /*鱼与熊掌不可兼得，试图扩大趋势利润总会让盘整利润失去
   if( t >= 0)
   {
      if( isClose() && OrderProfit()/OrderLots() >= TakeProfit*10) CloseOrder(OrderTicket(), 1-OrderType());
   }
   */
   bool ok1h = true;
   if( TimeSeconds(TimeCurrent())+TimeMinute(TimeCurrent())*60 <  60*60 - 80) ok1h = false; //MM2 MM3 is 1h system
   if( Enable_MM3 && ok1h)
   {
      int op3 = -1;
      int CBars = 240;
      double updown = iCustom(NULL, PERIOD_H1, "#Signal005-SHI_Channel", CBars, CBarsFrac, 3, 0);
      double tl1 = iCustom(NULL, PERIOD_H1, "#Signal005-SHI_Channel", CBars, CBarsFrac, 1, 0);
      double ReversePercent3 = 0; //反趋势系统，不反手
      if( updown == -1)
      {
         if( Bid > tl1) op3 = 1;
      }
      else if(updown == 1)
      {
         if( Ask < tl1) op3 = 0;
      }

      if( op3 != -1) 
      {
         //if( TimeCurrent() - dp > 60){
            //Print("==========tl1=",tl1,"tl2=",tl2,"updown=",updown);
            //dp = TimeCurrent();
         //}
         int t3 = GetOrder(MAGICMC, OP_SELL);
         if( t3 == -1 )
         {
               comment3 = "BollerTradeMM3:new "+ss[op3]+" order";
               OpenOrder(op3, Lots, StopLoss, TakeProfit, MAGICMC, ReversePercent3, comment3);
         }
         else
         {
               comment3 = "BollerTradeMM3:close "+ss[1-op3]+" order ["+t3+"]";
               OpenReverseOrder(t3, op3, Lots, StopLoss, TakeProfit, MAGICMC, ReversePercent3, comment3);
         }
      }
   }
   int op = -1;
   {
      //double objPrice = iMA(NULL,0,TradeMAPeriod,0,MODE_SMA,PRICE_CLOSE, 0);//iBands(NULL,0,TradeMAPeriod,2,0,PRICE_CLOSE,MODE_LOWER,0);
      int ind = iCustom(NULL, 0, "#Signal003-MA97", TradeMAPeriod,TakeProfit,StopLoss,AddRate,updownLevel,updowncount,shortma,shortmashift, cbars, 5, 0);
      if (ind == 0) {
                  //Alert(Symbol() + "到达上方价格 " + DoubleToStr(objPrice, 4) + "，现价为：" + DoubleToStr(Close[0], 4));
                  PlaySound("alert");
                  op = OP_BUY;
      }
      else if (ind == 1) {
                  //Alert(Symbol() + "到达下方价格 " + DoubleToStr(objPrice, 4) + "，现价为：" + DoubleToStr(Close[0], 4));
                  PlaySound("alert");
                  op = OP_SELL;
      }
      //log(2, StringConcatenate("ind=",ind," op=",op));
   }
   //if( StringFind(TimeToStr(Time[0], TIME_DATE|TIME_MINUTES), "2013.12.06 09") >= 0) 
   {
     //Print("trend ======",trend,"---p--",p,"-isUp(TradeMAPeriod)--",isUp(TradeMAPeriod),"isDown(TradeMAPeriod)",isDown(TradeMAPeriod),"Close",Close[0],"@",TimeToStr(Time[0],TIME_DATE|TIME_MINUTES));
   }
   if( manOrder == 2){
      op = manOrderOp;
      manOrder = 0;
   }
   int trend = 1;
   if( op != -1 && Enable_MM1 ) 
   {
      int t = GetOrder(MAGICMA, OP_SELL);
      //double angle = iCustom(NULL, 0, "MA_Angle", 97, 48, 2, 0, 0);
      if( t == -1 ){
            comment = "BollerTrade:"+sss[trend]+"new "+ss[op]+" order";
            OpenOrder(op, lots, sl, tk, MAGICMA, RevPercent, comment);
      }
      else{
            comment = "BollerTrade:"+sss[trend]+"Reverse "+ss[op]+" order "+"[org:"+ss[OrderType()]+" order "+t+"]";
            OpenReverseOrder(t, op, lots, sl, tk, MAGICMA, RevPercent,comment);
      }
      if( TimeCurrent() - ptime > 360)
      {
         ptime = TimeCurrent();
         Print(comment,"@",TimeToStr(ptime));
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