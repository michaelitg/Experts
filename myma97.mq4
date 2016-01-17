//适合震荡比较大的市场，有无趋势均可，但是对于单边的慢牛行情会有大亏损。

#include<stdlib.mqh>
extern string version = "1.002 05/26/2014";
extern bool   EnableMM1 = TRUE;
extern bool   EnableMM2 = FALSE;
extern int    ADXPeriod = 12;
extern double ADXRange  = 28;
extern double ADXRangeHigh  = 38;
extern double ADXRangeLow  = 20;
extern double MARange = 6;
extern double StopLoss = 60;
extern double TkRate = 4;
extern double SignalSpace = 10; //110 for gold;
extern double Lots =  1;
extern int    MAPeriod = 180;
extern double MACDOpenLevel =3;
extern bool   NotifyPhone = FALSE;
extern bool   macdCheck = FALSE;
extern int    KFilter = 4;
extern double AddPercent = 0.2; //Add Plan trade lots percent
extern double AddRate = 0.2;   //Add Plan mark position
extern double LimitRate = 0.2;  //Add Plan trade position up limit
extern double  ProtectPercent = 1;
extern double  thirdLots = 1; 
extern double ATRTimeFrame=240;
extern double ATRPeriod = 20;
extern double ATRRange = 100;
extern string skiptime1 = "2013.12.18,2014.01.29,2014.03.19,2014.04.30,2014.06.18";//非农和美联储决议 

/*
extern int    TrendK = 10;
extern double TrendRange = 10;
*/
#define MAGICMA  20140501
#define MAGICMB  20140502
#define MAGICMC  20140503

int skipn = 0;
datetime pt, st;
datetime dt = 0, dt2 = 0;

/*

1/初始版本:50/110/5  2013/11/25-2014/5/22 1600->18800
2/改进:距离太近的信号忽略,添加KFilter过滤参数 17980同时减少了连续亏损
3/改进：大跌/大涨之后前n各信号过滤掉 ==> 不具备普遍的操作性,放弃
4/加入了加仓，一下子盈利就上来了
5/根据日线ATR来调整StopLoss和TkRate
6/加入了MM2
7/试图用大K线过滤,失败,大K线过滤掉亏损,也过滤掉赢利
8/试图用adx过滤，问题同上，所以机械交易系统是唯一赢利的系统，因为是基于统计概率，而不是准确率

*/

bool skiptime(string skiptime)
{
   bool action = false;
   int len = StringLen(skiptime);
   int d = 0;
   for(int j = 0; j < len; j+=11)
   {
      string s = StringSubstr(skiptime, j, 10);
      if( StringFind(TimeToStr(TimeCurrent(), TIME_DATE), s) == 0)
      {
         action = true;
         break;
      }
      if( StringFind(TerminalName(), "FOREX") >= 0){
         if (TimeHour(TimeCurrent()) < 8)  //对于Forex平台，比标准时间多8个小时，必须考虑进去
         {
            MqlDateTime strt;
            TimeToStruct(TimeCurrent(), strt);
            strt.day = strt.day - 1;
            string a = TimeToStr(StructToTime(strt), TIME_DATE);
            if( StringFind(a, s) == 0)
            {
               action = true;
               break;
            }
         }
      }
   }

      /*debug
      if( TimeCurrent() - ptime2 > 360)
      {
         ptime2 = TimeCurrent();
         Print(TimeToStr(TimeCurrent(), TIME_DATE), skiptime1, "d=",d);
      }
      */
  if ( TimeDayOfWeek(TimeCurrent()) == 5 && TimeDay(TimeCurrent()) > 1 && TimeDay(TimeCurrent()) < 9 )
  {
     //if (TimeHour(TimeCurrent()) >= 8 && TimeHour(TimeCurrent()) <= 18)  //limit the hours only
     {
         action = true;
     }
  }
  if(action)
  {
      int totalOrders = OrdersTotal();
      for(int i=0;i<totalOrders;i++)
        {
         if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==false) break;
         if( OrderSymbol()!=Symbol() ) continue;
         Print("*****************skip time close order ************************");
         //---- check order type 
         if( OrderType() <= OP_SELL) 
         {
            double price = Ask;
            if( OrderType() == OP_BUY) price = Bid;
            if( OrderClose(OrderTicket(),OrderLots(),price,50,White) != true)
            {
               Print("Close order ",OrderTicket(), "error:",ErrorDescription(GetLastError()));
            }
         }
         else
            if( OrderDelete(OrderTicket()) != true)
            {
               Print("Delete order",OrderTicket(), " error:",ErrorDescription(GetLastError()));
            }
        }
      return(true);
  }
  return(false);
}

int init()
{
         //if( AccountEquity() >= 5000) Lots = Lots*10;
         return(0);
}
bool isBigTrend()
{
   if( !EnableMM1 ) return true;
   if( TimeCurrent() - Time[0] <  Period()*60 - 60) return true;
   return false;
   /*
   double s = High[iHighest(Symbol(), 0, MODE_HIGH, TrendK,0)] -Low[iLowest(Symbol(), 0, MODE_LOW, TrendK, 0)];
   if( s < TrendRange) return true;
   return false;
   */
}

double getPoint()
{
      double point=MarketInfo(Symbol(),MODE_POINT);
      if( point <= 0.0001) point = 0.0001;
      else point = 0.01;
      if( Ask > 800 && Ask < 1500) point = 0.1;  //gold
      if( Ask > 1500) point = 1;
      return(point);
}

//检查是否有在n根K线内平仓的单子
int getHistoryOrder(int mag)
{
   int hstTotal=OrdersHistoryTotal();
   int i;
   int k = hstTotal-10;
   if(k < 0) k = 0;
   for( i = hstTotal-1; i >= k; i--){
        if(OrderSelect(i,SELECT_BY_POS,MODE_HISTORY)== true)
            if(OrderType()<=OP_SELL &&   // check for opened position 
               OrderSymbol()==Symbol())  // check for symbol
               {
                  if( (OrderMagicNumber()) == mag)
                  {
                      if( CurTime() - OrderCloseTime() < KFilter * Period() * 60 ) return(OrderTicket());
                      //return(i);
                  }
               }
   }
   return(-1);
}

void OpenOrder(int op, double aLots, int aStopLoss, int aTakeProfit, int mag, string c="")
{
           double point = getPoint();
           double aprice, sl, tk;
           if( c == "") c = "myea openorder";
           int coef = 1;
           if( op == OP_BUY)
           {     
                  aprice = Ask;
                  sl = Ask - aStopLoss * point;
                  if( aTakeProfit > 0){
                     tk = Ask + aTakeProfit * point;
                  }
                  else tk = 0;
                  RefreshRates();
                  if(OrderSend(Symbol(), op, aLots*coef, NormalizeDouble(Ask, Digits), 500, sl, tk, c+"buy", mag) == -1)
                  { Print("myea Error = ",ErrorDescription(GetLastError())); }
           }
           if( op == OP_SELL)
           {
                  aprice = Bid;
                  sl = Bid + aStopLoss * point;
                  if( aTakeProfit > 0) tk = Bid - aTakeProfit * point;
                  else tk = 0;
                  RefreshRates();
                  if(OrderSend(Symbol(), op, aLots*coef, NormalizeDouble(Bid, Digits), 500, sl, tk, c+"sell", mag) == -1)
                  { Print("myea Error = ",ErrorDescription(GetLastError())); }
           }
           Print(c,"==point=",point,"==",Ask,"=lots=",aLots,"==op==",op,"==price=",aprice,"=sl=",sl,"==tk",tk);

}

int GetOrder(int mag, int maxType)
{
   for(int i=0;i<OrdersTotal();i++)
     {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==false) break;
      if( (mag != 0 && OrderMagicNumber()!= mag) || OrderSymbol()!=Symbol()) continue;
      //---- check order type 
      if( OrderType() <= maxType) return(OrderTicket());
     }
     return(-1);
}

void OpenReverseOrder(int ticket, int op, double aLots, int aStopLoss, int aTakeProfit, int mag,string c="")
{
      if( OrderSelect(ticket,SELECT_BY_TICKET, MODE_TRADES)==false )return;
      double lots = OrderLots();
      double opt = OrderProfit();
      int n;
      if( CurTime() - OrderOpenTime() < KFilter * Period() * 60) return;
      n = CloseOrder(ticket, op);
      
      if( n == 1 && opt < 0 ){
         lots = 2 * lots;
         //if( lots > MaxLots) lots = MaxLots;
      }
      else lots = aLots;
      Print("====myea-OpenReverseOrder","==lots=",lots,"==n=",n,"==op=",op);
      if( n > 0 )
      {
         OpenOrder(op, lots, aStopLoss, aTakeProfit, mag, c);
       }
}
int CloseOrder(int ticket, int op)
{
      int nClosed = 0;
      if( OrderSelect(ticket,SELECT_BY_TICKET, MODE_TRADES)==false )return(false);
      int mag = OrderMagicNumber();
      if(OrderType()==OP_BUY && op == OP_SELL)
        {
         if( OrderClose(OrderTicket(),OrderLots(),Bid,50,White) != true)
         {
            Print("Close order error:",ErrorDescription(GetLastError()));
         }
         nClosed++;
         int t = GetOrder(mag, OP_SELL);
         while( t >= 0)
         {
            if( OrderClose(OrderTicket(),OrderLots(),Bid,50,White) != true)
            {
               Print("Close order error:",ErrorDescription(GetLastError()));
            }
             nClosed++;
             t = GetOrder(mag, OP_SELL);
         }
         
         return(nClosed);
        }
      if(OrderType()==OP_SELL && op == OP_BUY)
        {

         if( OrderClose(OrderTicket(),OrderLots(),Ask,50,White) != true)
         {
            Print("Close order error:",ErrorDescription(GetLastError()));
         }
         nClosed++;
         t = GetOrder(mag, OP_SELL);
         while( t >= 0)
         {
            if( OrderClose(OrderTicket(),OrderLots(),Ask,50,White) != true)
            {
               Print("Close order error:",ErrorDescription(GetLastError()));
            }
             nClosed++;
             t = GetOrder(mag, OP_SELL);
         }
         return(nClosed);
        }
      return(nClosed);
}


int GetTotalOrders(int mag, int maxType)
{
   int totalOrders = 0;
   for(int i=0;i<OrdersTotal();i++)
     {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==false) break;
      if( (mag != 0 && OrderMagicNumber()!= mag) || OrderSymbol()!=Symbol()) continue;
      //---- check order type 
      if( OrderType() <= maxType) totalOrders++;
     }
     return(totalOrders);
}
bool checkAdd(int mag, int op)
{
   //Print("checkAdd-------", OrderTicket(),"-",mag,"-",op);
   for(int i=0;i<OrdersTotal();i++)
     {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==false) break;
      if( (mag != 0 && OrderMagicNumber()!= mag) || OrderSymbol()!=Symbol()) continue;
      //---- check order type 
      if( OrderType() == op+2){return(true);}
     }
     return(false);
}

double symbolLots(int maxType)
{
   double lots = 0;
   for(int i = 0; i < OrdersTotal();i++)
   {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==false) break;
      if( OrderSymbol() != Symbol() || OrderType() > maxType) continue;
      lots += OrderLots();
   }
   return(lots);
}
double AddMaxLots(double protectPercent)
{
   double maxLots = MarketInfo(Symbol(), MODE_MAXLOT);
   double p = MarketInfo(Symbol(),MODE_MARGINREQUIRED);
   double curLots = symbolLots(OP_SELLSTOP);
   if( AccountEquity() > 5000){ protectPercent /= 2;}
   //available amount is the freemargin substract the possible swing vol of current position
   double amount = AccountFreeMargin() - curLots * p * protectPercent;
   amount = amount*AddPercent;
   /*
      if( TimeCurrent() - dt > 1500)
      {
         dt = TimeCurrent();
         double a = (1 + protectPercent) * p;
         Print("AddMaxLots--------free=",AccountFreeMargin(),"a=",a,"curLots=",curLots, "protectPercent=",protectPercent, "addPercent=",AddPercent,"amount=",amount);
      }
   */   
   double optLots = MathCeil( amount /  p );
   if( optLots > maxLots) optLots = maxLots;

   return(optLots);
}
double getOrderPoint()
{
      double point=MarketInfo(OrderSymbol(),MODE_POINT);
      if( point <= 0.0001) point = 0.0001;
      else point = 0.01;
      if( OrderOpenPrice() > 800) point = 0.1;  //gold
      return(point);
}

int GetLastOrder(int mag, int maxType)
{
   for(int i=OrdersTotal()-1;i>=0;i--)
     {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==false) break;
      if( (mag != 0 && OrderMagicNumber()!= mag) || OrderSymbol()!=Symbol()) continue;
      //---- check order type 
      if( OrderType() <= maxType) return(OrderTicket());
     }
     return(-1);
}

void AddOrder2(int mag, double aAddRate, int aTakeProfit, double rate, double limit, string c="", double minPercent=0.5, double thirdlots = 0)
{
   int t, total;
   double m = MarketInfo(Symbol(), MODE_MAXLOT);
   total = GetTotalOrders(mag, OP_SELL);
   if( total == 0 || total >= 3) return;
   double lots = AddMaxLots(minPercent);
   if( lots <= 0) return;
   double coef = 1;
   if( c== "") c = "Add ";
   t = GetOrder(mag, OP_SELL);
   double tk = OrderTakeProfit();
   double point = getOrderPoint(); 
   //Print("=====coef=",coef,"==OrderLots==",OrderLots(),"====",OrderProfit() / (OrderLots() * coef),"=====",aAddRate * aTakeProfit);
   { 
   if( total < 2 )  // 第一次加仓
   {
      if( TimeCurrent() - dt2 <= 600) return;
      dt2 = TimeCurrent();
      RefreshRates();
      if( OrderSelect(t, SELECT_BY_TICKET, MODE_TRADES) == FALSE){
       Print("AddOrder2 failed0: ",ErrorDescription(ErrorDescription(GetLastError())));
       return;
      }
      /*
      {
         Print("AddOrder2*************: lots=",lots,"open=",OrderOpenPrice(),"ask=",Ask,"bid=",Bid,"orderprofit=",OrderProfit(),"profit=",OrderProfit() / (OrderLots() * coef));
         Print("AddOrder2************2: aAddRate * aTakeProfit=",aAddRate * aTakeProfit," (aAddRate+limit) * aTakeProfit", (aAddRate+limit) * aTakeProfit);
      }
      */
      if(OrderProfit() / (OrderLots() * coef) > aAddRate * aTakeProfit && OrderProfit() / (OrderLots() * coef) < (aAddRate+limit) * aTakeProfit )
      {
            if( OrderSelect(t, SELECT_BY_TICKET, MODE_TRADES) == FALSE){
             Print("AddOrder2 failed0: ",ErrorDescription(ErrorDescription(GetLastError())));
             return;
            }
            Print(c, "Add2原单[",t,"][",OrderTicket(),"]:OrderType=",OrderType(),"OrderProfit=",OrderProfit(), "-",aAddRate,"-",lots,"-",mag);
            //Print("xxodstoploss",OrderStopLoss(),"xxodopenprice",OrderOpenPrice(),"xx",Ask - OrderOpenPrice(),"++Ask=",Ask,"++rate=",rate,"++",aTakeProfit,"++",point,"++",Ask-(rate*aTakeProfit*point));
            if( OrderType() == OP_BUY) 
            {
               if( OrderSend(Symbol(),OP_BUY,lots, NormalizeDouble(Ask,Digits),50,NormalizeDouble(OrderStopLoss(),Digits), tk,c+"buy",mag,0,Blue) == -1)
               { Print("Send order error: ", ErrorDescription(GetLastError()));
               }
            }
            else{
               if(  OrderSend(Symbol(),OP_SELL,lots,NormalizeDouble(Bid,Digits),50,NormalizeDouble(OrderStopLoss(),Digits),tk,c+"sell",mag,0,Red) == -1)
                           { Print("Send order error: ", ErrorDescription(GetLastError()));
                           }
            }
            Sleep(10000);
      }
    }
    else
    {
      if( TimeCurrent() - dt2 <= 600) return;
      dt2 = TimeCurrent();
      if( thirdlots > 0)
      {
         if( getHistoryOrder(mag) > 0) return;
         RefreshRates();
         if( OrderSelect(t, SELECT_BY_TICKET, MODE_TRADES) == FALSE){
          Print("AddOrder2 failed2: ",ErrorDescription(ErrorDescription(GetLastError())));
          return;
         }
         /*
            {
               Print("AddOrder2-2*************: lots=",lots,"open=",OrderOpenPrice(),"ask=",Ask,"bid=",Bid,"orderprofit=",OrderProfit(),"profit=",OrderProfit() / (OrderLots() * coef));
               Print("AddOrder2-2************2: aAddRate * aTakeProfit=",aAddRate * aTakeProfit," (aAddRate+limit) * aTakeProfit", (aAddRate+limit) * aTakeProfit);
            }
         */
         if(OrderProfit() / (OrderLots() * coef) > aAddRate * aTakeProfit && OrderProfit() / (OrderLots() * coef) < (aAddRate+limit) * aTakeProfit )
         {
               int t2 = GetLastOrder(mag, OP_SELL);
               double newlots = lots * thirdlots;
               if( newlots > 0 && newlots + symbolLots(OP_SELL)  < m)
               {
                  if( OrderSelect(t, SELECT_BY_TICKET, MODE_TRADES) == FALSE){
                     Print("AddOrder2 failed3: ",ErrorDescription(ErrorDescription(GetLastError())));
                     return;
                  }
                  double sl = OrderOpenPrice();  //the first order open price as stoploss
                  Print(c, "Add2-2原单[",t,"][",OrderTicket(),"]op=",OrderType(),"ask=",Ask,"bid=",Bid,"-",aAddRate,"lots=",newlots,"-",mag);
                  if( OrderType() == OP_BUY)
                  {
                     if(OrderSend(Symbol(),OP_BUY,newlots, Ask,0,sl-5*Point, tk,c+"2nd add buy",mag,0,Blue) == -1)
                              { Print("Send order error: ", ErrorDescription(GetLastError()));
                              }
                  }else
                  {
                      if( OrderSend(Symbol(),OP_SELL,newlots,Bid,0,sl+50*Point,tk,c+"2nd add sell",mag,0,Red) == -1)
                              { Print("Send order error: ", ErrorDescription(GetLastError()));
                              }
                  }
                }
               Sleep(10000);
          }
      }
    }
  } 
}

void ClosePendingOrder(int mag, bool force=false)
{
   int t = GetOrder(mag, OP_SELL);
   if( force == false && t >= 0) return;
   
   int at[100];
   int k = 0;
   bool done = false;
   while( !done)
   {
   done = true;
   for( int i = 0; i < OrdersTotal(); i++)
   {
      if( OrderSelect(i, SELECT_BY_POS, MODE_TRADES)==false )return;
      double point = getOrderPoint();
      //if( TimeCurrent() - pc > 360)
      //{
         //pc = TimeCurrent();
         //Print("========xxxxxxxticket=",OrderTicket(),"mag=",OrderMagicNumber(),"type=",OrderType(),"sym=",OrderSymbol(),"point=",point);
      //}
      if(OrderType()<= OP_SELL || OrderSymbol() != Symbol() || OrderMagicNumber() != mag ) continue;
      if( MathAbs( OrderOpenPrice() - Ask ) / point > 20)  //保留了价格接近的挂单
      {
            //Print("=====t=",t,"====",mag, "----", OrdersTotal(), "--",OrderTicket());
            if(OrderDelete(OrderTicket())!=true)
            {
               Print("Delete order error:",ErrorDescription(GetLastError()));
            }
            done = false;
            break;
      }
   }
   }
}

double myATR(int t, int s, int p)
{
   int i;
   double c1, max, tmax;
   max = 0;
   tmax = 0;
   for( i = s; i <= p+s; i++)
   {
      max = iHigh(Symbol(), t, i) - iLow(Symbol(), t, i);
      c1 = MathAbs(iHigh(Symbol(), t, i) - iClose(Symbol(), t, i+1));
      if( max < c1) max = c1;
      c1 = MathAbs(iLow(Symbol(), t, i) - iClose(Symbol(), t, i+1));
      if( max < c1) max = c1;
      tmax += max; 
   }
   return tmax; //return(tmax / p);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int start()
  {
   string comment;
   comment = "ma55:加仓";
   //MM1 trend trade, add position
   ClosePendingOrder(MAGICMA);
   AddOrder2(MAGICMA, AddRate, TkRate*StopLoss, 0, LimitRate,comment,ProtectPercent,thirdLots);
   //MM2 swing, do not add position
   
   while( TimeCurrent() - Time[0] > 60 && TimeCurrent() - Time[0] <  Period()*60 - 60 ) return(0);
   if( skiptime(skiptime1)){
      return(0);
   }
   //common
      string ss[2];
      ss[0] = "买"; ss[1]="卖";
      double a = myATR(ATRTimeFrame, 0, ATRPeriod);
      double r = TkRate * a / ATRRange;
      if( ATRRange > 1000) r = TkRate;
      int sl, tk , t;
      double lot;
      
   //MM2 wpr swing trade
   if( EnableMM2 && TimeCurrent() - Time[0] < 60 )
   {
      double signalWpr = iCustom(Symbol(), 0, "0ma55", MAPeriod, 1.1, 4, 1);
      int opwpr = -1;
      double adx = iADX(Symbol(), 0, ADXPeriod, PRICE_CLOSE, MODE_MAIN,1);
      double ma55 = iMA(Symbol(), 0, MAPeriod , 0, MODE_SMA, PRICE_CLOSE, 1);
      if( signalWpr >= -6 && signalWpr <= 6 && adx > ADXRangeLow && adx < ADXRangeHigh && MathAbs(Close[1] - ma55) > MARange)
      {
         double adx2 = iADX(Symbol(), 0, ADXPeriod, PRICE_CLOSE, MODE_MAIN,2);
         //if( adx > ADXRange && adx < ADXRangeHigh && adx > adx2)  //趋势很强，把震荡信号反过来做
         if( adx > ADXRange  && adx > adx2)  //趋势很强，把震荡信号反过来做  
         {
              if( signalWpr < 0) opwpr = 0;
              else opwpr = 1;      
              sl = StopLoss * 2; // MathAbs(Close[0] - objPrice) / Point / 10 + StopLoss;
              tk = sl * r;
         }
         else  //震荡中，或趋势反转，按照震荡信号交易
         {
            if( signalWpr < 0) opwpr = 1;
            else opwpr = 0;
            sl = StopLoss * 3; // MathAbs(Close[0] - objPrice) / Point / 10 + StopLoss;
            tk = StopLoss * r;
         }

         string ss2[2];
         ss2[1] = "WPR空头信号";
         ss2[0] = "WPR多头信号";
         
         t = GetOrder(MAGICMB, OP_SELL);
         //lot= NormalizeDouble( Lots*(1 + AccountEquity()/10000), 1);
         
         datetime now = TimeCurrent();
         if( now - pt > 60 )
         {  
            pt = now;
            Print("****************wprsignal adx2=[",adx2,"]**adx=[",adx,"]@",TimeToStr(Time[0])); 
            if( t > 0){
               if( opwpr == OrderType())
               {
                  if( adx < ADXRange )
                  {
                     int tt = GetTotalOrders(MAGICMB, OP_SELL);
                     if( tt % 2 == 1) lot = NormalizeDouble( lot / 2, 1);
                     else lot = lot * 2;
                     comment = "ma55:"+ss2[opwpr]+"加"+ss[opwpr]+"单";
                     OpenOrder(opwpr, lot, sl, tk, MAGICMB, comment);
                  }
               }
               else
               {
                  comment = "ma55:"+ss2[opwpr]+"反手开"+ss[opwpr]+"单"+"[原"+ss[OrderType()]+"单"+t+"]";
                  OpenReverseOrder(t, opwpr, lot, sl, tk, MAGICMB,comment);
               } 
            } 
            else{
                  comment = "ma55:"+ss2[opwpr]+"新"+ss[opwpr]+"单";
                  OpenOrder(opwpr, lot, sl, tk, MAGICMB, comment);
            }
         }
      }
   }
   //MM1 ma55 trend trade
   int op = -1;
   int orderk = 0; //order k = 0
   double objPrice = iMA(Symbol(), Period(), MAPeriod , 0, MODE_SMA, PRICE_CLOSE, orderk);

   if (((False) || Close[orderk+1] < objPrice) && Close[orderk] > objPrice + SignalSpace*Point ){
                  op = OP_BUY;
   }
   if (((False) || Close[orderk+1] > objPrice) && Close[orderk] < objPrice - SignalSpace*Point ){
                  op = OP_SELL;
   }
   if( macdCheck)
   {
      double macd = iMACD(Symbol(), Period(), 24, 52, 9, PRICE_CLOSE, MODE_MAIN,orderk );
      if( macd > 0 && op == 1) op = 0;
      else if( macd < 0 && op == 0) op = 1;
      else op = -1;
   }
   /*
   double MacdCurrent,MacdPrevious;
   double SignalCurrent,SignalPrevious;
   MacdCurrent=iMACD(Symbol(),0,24,52,9,PRICE_CLOSE,MODE_MAIN,0);
   MacdPrevious=iMACD(Symbol(),0,24,52,9,PRICE_CLOSE,MODE_MAIN,1);
   SignalCurrent=iMACD(Symbol(),0,24,52,9,PRICE_CLOSE,MODE_SIGNAL,0);
   SignalPrevious=iMACD(Symbol(),0,24,52,9,PRICE_CLOSE,MODE_SIGNAL,1);
   if(MacdCurrent<0 && MacdCurrent>SignalCurrent && MacdPrevious<SignalPrevious && 
         MathAbs(MacdCurrent)>(MACDOpenLevel*Point) )
         op = 0;
   if(MacdCurrent>0 && MacdCurrent<SignalCurrent && MacdPrevious>SignalPrevious && 
         MacdCurrent>(MACDOpenLevel*Point) )
         op = 1;
   */
   while( op != -1 && !isBigTrend() ) 
   {
      sl = StopLoss; // MathAbs(Close[0] - objPrice) / Point / 10 + StopLoss;
      //tk = sl * r;
      tk = sl * TkRate;
      string s[2];
      s[0] = "上破55均线"; s[1] = "下破55均线";
      /*adx = iADX(Symbol(), 0, ADXPeriod, PRICE_CLOSE, MODE_MAIN,0);
      if( adx < ADXRangeLow ){
         if( CurTime() - pt > 3600 )
         { 
            pt = CurTime();
            //Print(Close[1],"objPrice=",objPrice,"-",Close[0],"--",objPrice + SignalSpace*Point);
            skipn++;
            Print("------------------------------skip ",skipn," due to adx ", adx);
         }
         break;
      }*/
      t = GetOrder(MAGICMA, OP_SELL);
      //double angle = iCustom(NULL, 0, "MA_Angle", 97, 48, 2, 0, 0);
      lot = Lots;
      //lot= NormalizeDouble( Lots*(1 + AccountEquity()/10000), 1);
      if( t == -1 ){
               if( getHistoryOrder(MAGICMA) > 0) return 0;
               comment = "ma55:"+s[op]+"新"+ss[op]+"单";
               OpenOrder(op, lot, sl, tk, MAGICMA, comment);
         }
         else{
               comment = "ma55:"+s[op]+"反手开"+ss[op]+"单"+"[原"+ss[OrderType()]+"单"+t+"]";
               OpenReverseOrder(t, op, lot, sl, tk, MAGICMA,comment);
         }
      break;
   }
   return(0);
  }
// the end.