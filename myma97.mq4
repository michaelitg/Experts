#include<stdlib.mqh>
extern string version = "1.04 01/25/2016";
extern double StopLoss = 70;  //M15 - 80 H1 - 70
extern double TkRate = 3;  //M15 -2 H1 - 3
extern int    MAPeriod = 200;
extern int    RunPeriod = 60;
extern double MaxLots = 4;
extern double MaxTotalLots = 60;
extern double SignalSpace = 10; //110 for gold;
extern int    SignalOffset = 5;
extern int    MA_FAST = 1;
extern double Lots =  1;
extern int    shortma = 0;
extern int    shortmashift = 3;
extern double MACDOpenLevel =3;
extern bool   NotifyPhone = FALSE;
extern bool   macdCheck = FALSE;
extern int    KFilter = 5;
extern int    AddMa = 15;
extern double AddPercent = 0.2; //Add Plan trade lots percent
extern double AddRate = 0.1;   //Add Plan mark position
extern double LimitRate = 0.2;  //Add Plan trade position up limit
extern double  ProtectPercent = 1;
extern double  thirdLots = 1; //第二次加仓的倍数
extern int    manOrder = 0;   //
extern string comment11 = "manOrderOp=0-Buy 1-Sell";
extern int    manOrderOp = 0;  
//extern string skiptime1 = "2014.04.30,2014.06.18";//非农和美联储决议 

#define MAGICMA  20140501

int skipn = 0;
datetime pt, st;
datetime dt = 0, dt2 = 0;
datetime ptime1 = 0;
datetime ptime2 = 0;
datetime ptime3 = 0;
datetime ptime4 = 0;
datetime dtime1 = 0;
datetime dtime2 = 0;
datetime dtime3 = 0;
datetime lasttime = 0;

/*
//适合震荡比较大的市场，有无趋势均可，但是对于单边的慢牛行情没有信号。
1/初始版本:50/110/5  2013/11/25-2014/5/22 1600->18800
2/改进:距离太近的信号忽略,添加KFilter过滤参数 17980同时减少了连续亏损
3/改进：大跌/大涨之后前n各信号过滤掉 ==> 不具备普遍的操作性,放弃
4/加入了加仓，一下子盈利就上来了
5/根据日线ATR来调整StopLoss和TkRate
6/加入了MM2
7/试图用大K线过滤,失败,大K线过滤掉亏损,也过滤掉赢利
8/试图用adx过滤，问题同上，所以机械交易系统是唯一赢利的系统，因为是基于统计概率，而不是准确率
9/使用ma来决定是否加仓，而不是到了点位就加
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

double getPoint()
{
      double point=MarketInfo(Symbol(),MODE_POINT);
      if( point <= 0.0001) point = 0.0001;
      else point = 0.01;
      if( Ask > 800 && Ask < 1500) point = 0.1;  //gold
      if( Ask > 1500) point = 1;
      return(point);
}

//检查是否有在n根K线内平仓的同向亏损的单子
int checkHistoryOrder(int mag, int aKFilter, int op)
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
                      if( CurTime() - OrderCloseTime() < aKFilter * Period() * 60 )
                      {
                         if( OrderType() == op && OrderProfit() < 0) return(OrderTicket());
                      }
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
      //if( CurTime() - OrderOpenTime() < KFilter * Period() * 60) return;
      n = CloseOrder(ticket, op);
      
      if( n == 1 && opt < 0 ){
         lots = 2 * lots;
         if( lots > MaxLots) lots = MaxLots;
      }
      else lots = aLots;
      //Print("====myea-OpenReverseOrder","==lots=",lots,"==n=",n,"==op=",op);
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
      double p = OrderOpenPrice();
      if( p > 800 && p < 1500) point = 0.1;  //gold
      if( p > 1500) point = 1;
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
      if( TimeCurrent() - dt2 <= 6000) return;
      dt2 = TimeCurrent();
      if( thirdlots > 0)
      {
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
   comment = "myma97:";
   Comment( comment+version);
   ///check if we need to open order manually
   if( manOrder == 1)
   {
        int tt = GetOrder(MAGICMA, OP_SELL);
        if( tt == -1 )
            OpenOrder(manOrderOp, Lots, StopLoss, StopLoss*TkRate, MAGICMA, comment+"manual order");
        manOrder = 0;
        return(0);
   }
   if( Period() != RunPeriod ) return(0);

   //check for adding position
   //ClosePendingOrder(MAGICMA);
   AddOrder(MAGICMA, AddRate, TkRate*StopLoss, 0.1, LimitRate,comment+"加仓",ProtectPercent,thirdLots,MaxTotalLots);

   //open position
   RefreshRates();
   if(TimeCurrent() - Time[0] <  Period()*60 - 60) return(0);  
   //if( skiptime(skiptime1)){
   //   return(0);
   //} 
   
   string ss[2];
   ss[0] = "买"; ss[1]="卖";
   int sl, tk , t;
   double lot;
      
   int op = -1;
   if( true )  //trend == 1
   {
      if (isUp(MAPeriod)) {
          //Alert(Symbol() + "到达上方价格 " + DoubleToStr(objPrice, 4) + "，现价为：" + DoubleToStr(Close[0], 4));
          PlaySound("alert");
          op = OP_BUY;
      }
      else if (isDown(MAPeriod)) {
          //Alert(Symbol() + "到达下方价格 " + DoubleToStr(objPrice, 4) + "，现价为：" + DoubleToStr(Close[0], 4));
          PlaySound("alert");
          op = OP_SELL;
      }
   }
   if( macdCheck)
   {
      double macd = iMACD(Symbol(), Period(), 24, 52, 9, PRICE_CLOSE, MODE_MAIN,0 );
      if( macd > 0 && op == 1) op = 0;
      else if( macd < 0 && op == 0) op = 1;
      else op = -1;
   }

   while( op != -1 ) 
   {
      sl = StopLoss; // MathAbs(Close[0] - objPrice) / Point / 10 + StopLoss;
      tk = sl * TkRate;
      string s[2];
      s[0] = "上破均线"; s[1] = "下破均线";
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
               
               if( KFilter > 0 && checkHistoryOrder(MAGICMA, KFilter, op) > 0){
                   if( TimeCurrent() - dtime3 > 80)
                   {
                     dtime3 = TimeCurrent();
                     Print("myma97: skip the singal since we just close an loss order op=",op);
                   } 
                   return 0;
               }
               
               comment += s[op]+"新"+ss[op]+"单";
               OpenOrder(op, lot, sl, tk, MAGICMA, comment);
         }
         else{
               comment += s[op]+"反手开"+ss[op]+"单"+"[原"+ss[OrderType()]+"单"+t+"]";
               OpenReverseOrder(t, op, lot, sl, tk, MAGICMA,comment);
         }
      break;
   }
   return(0);
  }
  
//signal
bool isUp(int pd)
{
   double p, p2;
     
   for( int i = 2; i >= 0; i--)
   {
      p = iMA(Symbol(),0,pd,0,MODE_SMA,PRICE_CLOSE, i); 
      //double t = Open[i];
      //if( t < Close[i]) t = Close[i];
      //if( High[i] - t > factor*MathAbs(Open[i] - Close[i])) break;
      p2 = iMA(NULL,0,MA_FAST,0,MODE_SMA,PRICE_CLOSE, i);   
      //p2 = Close[i];
      if(p2 <= p - SignalSpace/2) break;
      //test if(Close[i+1] <= p ) break;
      //if(Close[i] < p + 0.1) break;
   }
   if( i == -1)
   { 
      p2 = iMA(NULL,0,MA_FAST,0,MODE_SMA,PRICE_CLOSE, SignalOffset);   
      //p2 = Low[SignalOffset];
     if(p2 < p && Close[0] > p + SignalSpace)
     //test if(Close[i+1] < p && Close[0+1] > p + updownLevel)
     {
          //飞吻行情过滤
         if(  shortma > 0)
         {
            double s = iMA(Symbol(),0, shortma,0,MODE_SMA,PRICE_CLOSE, shortmashift);
            if( s > p ){
               if( TimeCurrent() - ptime3 > 360)
               {
                  ptime3 = TimeCurrent();
                  Print("xxxxxxxshortma skip this Up signal @",TimeToStr(TimeCurrent(), TIME_DATE | TIME_MINUTES));
               }
               return(false);
            }
         }
         /*
         if( TimeDay(TimeCurrent()) == 16 &&  TimeCurrent() - ptime2 >= 80)
         {
            ptime2 = TimeCurrent();
            Print("isUp---true---------i=",i,"ma=",p,"close=",Close[0],"close5=",Close[5]);
         }
         */
         return(true);
     }    
   }
   /*
   if( TimeDay(TimeCurrent()) == 16 && TimeCurrent() - ptime1 >= 80)
   {
      ptime1 = TimeCurrent();
      Print("isUp----------------i=",i,"ma=",p,"close=",Close[0],"close5=",Close[5]);
   }
   */
   return(false);
}

bool isDown(int pd)
{
   double p,p2;

   for( int i = 2; i >= 0; i--)
   {
      p = iMA(NULL,0,pd,0,MODE_SMA,PRICE_CLOSE, i);      
      p2 = iMA(NULL,0,MA_FAST,0,MODE_SMA,PRICE_CLOSE, i);   
      //p2 = Close[i];
      if(p2 >= p + SignalSpace/2 ) break;
      //if(Close[i] >= p + SignalSpace/2 ) break;
      
   }
   if( i == -1)
   {
     //p2 = High[SignalOffset];
     p2 = iMA(NULL,0,MA_FAST,0,MODE_SMA,PRICE_CLOSE, SignalOffset);
     if( p2 > p && Close[0] < p - SignalSpace)
     //test if(Close[i+1] > p && Close[0+1] < p - updownLevel)
     {
        
         //飞吻行情过滤
         if(  shortma > 0)
         {
            double s = iMA(NULL,0, shortma,0,MODE_SMA,PRICE_CLOSE, shortmashift);
            if( s < p ){
               if( TimeCurrent() - ptime4 > 360)
               {
                  ptime4 = TimeCurrent();
                  Print("xxxxxxxshortma skip this Down signal @",TimeToStr(TimeCurrent(), TIME_DATE | TIME_MINUTES));
               }
               return(false);
            }    
         }
         /*
         if( TimeMonth(TimeCurrent()) == 1 &&  TimeCurrent() - dtime2 >= 80)
         {
            dtime2 = TimeCurrent();
            Print("isDown---true---------i=",i,"ma=",p,"close=",Close[0],"close5=",Close[5]);
         }
         //*/
         return(true);
      }
   }
   /*
   if( TimeMonth(TimeCurrent()) == 1 &&  TimeCurrent() - dtime1 >= 80)
   {
      dtime1 = TimeCurrent();
      Print("isDown----------------i=",i,"ma=",p,"close=",Close[0],"close5=",Close[5]);
   }
   //*/
   return(false);
}

//AddOrder(MAGICMA, AddRate, TkRate*StopLoss, 0, LimitRate,comment+"加仓",ProtectPercent,thirdLots,MaxTotalLots);
void AddOrder(int mag, double aAddRate, int aTakeProfit, double rate, double limit, string c="", double minPercent = 0.5, double thirdlots = 0, double maxLots = 0)
{
   int t, total;
   total = GetTotalOrders(mag, OP_SELL);
   if( total == 0 || total >= 3) return;
   double lots = AddMaxLots(minPercent);
   if( lots <= 0) return;
   if( c== "") c = "Add ";
   t = GetOrder(mag, OP_SELL);
   double tk = OrderTakeProfit();
   double sl = OrderStopLoss();
   double point = getOrderPoint(); 

   if(OrderProfit() <= 0) return;
   //if( checkAdd(mag, OrderType())) return; //已经下过加仓的挂单，就返回
   int t2 = OrderTicket();
   double coef = 1;
  //Print("=====coef=",coef,"==OrderLots==",OrderLots(),"====",OrderProfit() / (OrderLots() * coef),"=====",AddRate * TakeProfit);
   double orderprofitperlot = iMA(Symbol(),0, AddMa, 0, MODE_SMA,PRICE_CLOSE, 1) - OrderOpenPrice();
   if( (OrderType() == OP_SELL && orderprofitperlot >= 0) || (OrderType() == OP_BUY && orderprofitperlot <= 0)) return;
   orderprofitperlot = MathAbs(orderprofitperlot);
   bool notdone = true;
   while(notdone)
   { 
   notdone = false;
   if( total < 2)  // 第一次加仓，挂单
   {
      RefreshRates();
      if( OrderSelect(t, SELECT_BY_TICKET, MODE_TRADES) == FALSE){
         Print("AddOrder2 failed0: ",ErrorDescription(GetLastError()));
         return;
      }
      if( TimeCurrent() - dt2 <= 800 || TimeCurrent() - OrderOpenTime() <= 800) return;
      if(orderprofitperlot > aAddRate * aTakeProfit && orderprofitperlot < (aAddRate+limit) * aTakeProfit )
      {
            if( OrderSelect(t, SELECT_BY_TICKET, MODE_TRADES) == FALSE){
             Print("AddOrder2 failed0: ",ErrorDescription(GetLastError()));
             return;
            }
            dt2 = TimeCurrent();
            Print(c, "Add2-1原单[",t,"]:OrderType=",OrderType(),"OrderProfit=",OrderProfit(), "orderprofitperlot=",orderprofitperlot,"lots=",lots,"AddRate=",aAddRate);
            if( OrderType() == OP_BUY) OrderSend(Symbol(),OP_BUY,lots, NormalizeDouble(Ask,Digits),50, sl, tk,c+"Add2-1原单["+t+"]",mag,0,Blue);
            else  OrderSend(Symbol(),OP_SELL,lots,NormalizeDouble(Bid,Digits),50, sl,tk,c+"Add2-1原单["+t+"]",mag,0,Red);
            Sleep(10000);
      }
    }
    else{  //已经加过仓，在回到达40%时再加仓
      if( TimeCurrent() - dt2 <= 6000 || thirdLots == 0) return;
      {
     double totalLots = 0;
     if( maxLots > 0)
     {
         for(int i=0;i<OrdersTotal();i++)
         {
          if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==false) break;
          if( OrderSymbol()!=Symbol()) continue;
          //---- check order type 
          if( OrderType() <= OP_SELL) totalLots += OrderLots();
         }
         if( totalLots >= maxLots )  return;
     }
      RefreshRates();
      if( OrderSelect(t, SELECT_BY_TICKET, MODE_TRADES) == FALSE){
       Print("AddOrder2 failed2: ",ErrorDescription(GetLastError()));
       return;
      }
      if(orderprofitperlot> AddRate * aTakeProfit && orderprofitperlot < (AddRate+limit) * aTakeProfit )
      {
            double newlots = lots*thirdLots;
            if( maxLots > 0 && newlots + totalLots > maxLots) newlots = maxLots - totalLots;
            if( newlots > 0)
            {
               if( OrderSelect(t, SELECT_BY_TICKET, MODE_TRADES) == FALSE){
                  Print("AddOrder2 failed3: ",ErrorDescription(GetLastError()));
                  return;
               }
               //sl = OrderOpenPrice();  //new method1 => decrease profit, but can avoid burst death
               dt2 = TimeCurrent();
               Print(c, "Add2-2原单[",t,"]op=",OrderType(),"ask=",Ask,"bid=",Bid,"-",AddRate,"lots=",newlots,"-",mag);
               if( OrderType() == OP_BUY) OrderSend(Symbol(),OP_BUY,newlots, Ask,0,sl, OrderTakeProfit(),c+"Add2-2原单["+t+"]",mag,0,Blue);
               else  OrderSend(Symbol(),OP_SELL,newlots,Bid,0,sl,OrderTakeProfit(),c+"Add2-2原单["+t+"]",mag,0,Red);
               //Print("Result:",ErrorDescription(GetLastError()));
               //if( OrderType() == OP_BUYSTOP) OrderSend(Symbol(),OP_BUYSTOP,lots, NormalizeDouble(Ask+(rate*TakeProfit*point),Digits),50,NormalizeDouble(OrderStopLoss(),Digits), tk,c+"buylimit2 position",mag,0,Blue);
               //else  OrderSend(Symbol(),OP_SELLSTOP,lots,NormalizeDouble(Bid-(rate*TakeProfit*point),Digits),50,NormalizeDouble(OrderStopLoss(),Digits),tk,c+"selllimit2 position",mag,0,Red);
            }
            Sleep(10000);
      }
      if( GetLastError() == 131){
          //lots = NormalizeDouble(lots / 2, 1);
          //notdone = true;
      }
      }
    }//else
  } //while
   /*
   if( OrderProfit() / (OrderLots() * 10) > TakeProfit )
   {
      int TrailingStop = TakeProfit;
      if( OrderType() == OP_BUY)
      { 
         if(OrderStopLoss()< Bid-point*TrailingStop)
         {
              OrderModify(OrderTicket(),OrderOpenPrice(),Bid-point*TrailingStop,0,0,Green);
         }
      }
      else{
         if((OrderStopLoss()>(Ask+point*TrailingStop)) )
         {
              OrderModify(OrderTicket(),OrderOpenPrice(),Ask+point*TrailingStop,0,0,Red);
         }
      }

   }
   */
}
  
// the end.