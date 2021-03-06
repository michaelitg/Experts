//Only for GER30

#include<stdlib.mqh>
extern string version = "1.02 01/19/2016";
extern double StopLoss = 100;// 80; 
extern double TkRate = 5; //6;  
extern int    MAPeriod = 240;
extern int    RunPeriod = 1;
extern int    RunMode = 1;
extern int    MaxConLoss = 4; //如果已经连续亏损超过3次，则说明震荡还是趋势看不清楚。也必须冷静一段时间
//extern double MaxTotalLots = 20;
extern double SignalSpace = 8; 
extern int    SignalOffset = 5;
extern double Lots =  1;
extern int    shortma = 0;
extern int    shortmashift = 3;
extern double MACDOpenLevel =3;
extern bool   NotifyPhone = FALSE;
extern bool   macdCheck = FALSE;
//extern int    KFilter = 0;
extern int    AddMa = 1;
extern double AddPercent = 0.1; //Add Plan trade lots percent
extern double AddRate = 0.4;   //Add Plan mark position
extern double LimitRate = 0.2;  //Add Plan trade position up limit
extern double  ProtectPercent = 1;
extern int    manOrder = 0;   //
extern string comment11 = "manOrderOp=0-Buy 1-Sell";
extern int    manOrderOp = 0;  
//extern string skiptime1 = "2014.04.30,2014.06.18";//非农和美联储决议 

#define MAGICMA  20160118

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
datetime dtime5 = 0;
datetime lasttime = 0;

int init()
{
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

int ClosePendingOrder(int mag)
{  
   int k = 0;
   bool done = false;
   int c = 0;
   while( !done)
   {
   done = true;
   RefreshRates();
   for( int i = 0; i < OrdersTotal(); i++)
   {
      if( OrderSelect(i, SELECT_BY_POS, MODE_TRADES)==false )return(c);
      double point = getOrderPoint();
      //if( TimeCurrent() - pc > 360)
      //{
         //pc = TimeCurrent();
         //Print("========xxxxxxxticket=",OrderTicket(),"mag=",OrderMagicNumber(),"type=",OrderType(),"sym=",OrderSymbol(),"point=",point);
      //}
      if(OrderType()<= OP_SELL || OrderSymbol() != Symbol() || OrderMagicNumber() != mag ) continue;
      //if( MathAbs( OrderOpenPrice() - Ask ) / point > 20)  //保留了价格接近的挂单
      {
            //Print("=====t=",t,"====",mag, "----", OrdersTotal(), "--",OrderTicket());
            if(OrderDelete(OrderTicket())!=true)
            {
               Print("Delete order error:",ErrorDescription(GetLastError()));
            }
            c++;
            done = false;
            Sleep(1000);
            break;
      }
   }
   }
   return c;
}

bool checkOpen(int mag, int op)
{
   //Print("checkAdd-------", OrderTicket(),"-",mag,"-",op);
   for(int i=0;i<OrdersTotal();i++)
     {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==false) break;
      if( (mag != 0 && OrderMagicNumber()!= mag) || OrderSymbol()!=Symbol()) continue;
      //---- check order type 
      if( OrderType() == op+4){return(true);}
     }
     return(false);
}

void OpenOrder(int op, double aLots, int aStopLoss, int aTakeProfit, int mag, string c="", bool forced = false)
{
           if( RunMode == 1 && forced == false)
           {
            OpenOrder2(op, aLots, aStopLoss, aTakeProfit, mag, c);
            return;
           }
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

int checkHistoryOrder(int mag)
{
   int hstTotal=OrdersHistoryTotal();
   int i;
   int k = hstTotal-10;
   int ng = 0;
   int buy = 0;
   int sell = 0;
   if(k < 0) k = 0;
   for( i = hstTotal-1; i >= k; i--){
        if(OrderSelect(i,SELECT_BY_POS,MODE_HISTORY)== true)
            if(OrderType()<=OP_SELL &&   // check for opened position 
               OrderSymbol()==Symbol())  // check for symbol
               {
                  if( (OrderMagicNumber()) == mag)
                  {
                      if( OrderProfit() > 10)
                      {  
                        break;
                      }
                      if( OrderType() == OP_BUY) buy++;
                      else sell++;
                      ng++;
                  }
               }
   }
   if( buy > sell)  return(ng);
   else return (-ng);
}
void OpenOrder2(int op, double aLots, int aStopLoss, int aTakeProfit, int mag, string c="")
{
           double p, point = getPoint();
           double aprice, sl, tk;
           if( c == "") c = "myea openorder";
           int coef = 1;
           if( checkOpen(mag, op) ) return;
           double lots = AddMaxLots(ProtectPercent);
           if( lots <= 0) return;
           if( op == OP_BUY)
           {     
                  aprice = Ask;
                  sl = Ask - aStopLoss * point;
                  if( aTakeProfit > 0){
                     tk = Ask + aTakeProfit * point;
                  }
                  else tk = 0;
                  RefreshRates();
                  p = Ask + AddRate * aTakeProfit * point;
                  if(OrderSend(Symbol(), OP_BUYSTOP, lots*coef, NormalizeDouble(p, Digits), 500, sl, tk, c+"buystop", mag) == -1)
                  { Print("myea Error = ",ErrorDescription(GetLastError())); }
           }
           if( op == OP_SELL)
           {
                  aprice = Bid;
                  sl = Bid + aStopLoss * point;
                  if( aTakeProfit > 0) tk = Bid - aTakeProfit * point;
                  else tk = 0;
                  RefreshRates();
                  p = Bid - AddRate * aTakeProfit * point;
                  if(OrderSend(Symbol(), OP_SELLSTOP, lots*coef, NormalizeDouble(p, Digits), 500, sl, tk, c+"sellstop", mag) == -1)
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
      int n = 0;
      //if( CurTime() - OrderOpenTime() < KFilter * Period() * 60) return;
      int ot = OrderType();
      if( ot >= 4){
         if( op+4 != ot) n = ClosePendingOrder(mag);
      }
      else   
         if( op != ot) n = CloseOrder(ticket, op);
      //Print("====myea-OpenReverseOrder","==lots=",lots,"==n=",n,"==op=",op);
      if( n > 0 )
      {
         double mlots = AddMaxLots(ProtectPercent);
         if( lots > mlots)
         {
            lots = mlots;
         }
         int hp = MathAbs(checkHistoryOrder(mag));
         OpenOrder(op, lots, aStopLoss, aTakeProfit, mag, c, ot<=1&&opt<0&&hp<MaxConLoss);
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
   double optLots = MathCeil( amount /  p );
   if( optLots > maxLots) optLots = maxLots;
   /*
      if( TimeCurrent() - dt > 1500)
      {
         dt = TimeCurrent();
         Print("AddMaxLots--------free=","curLots=",curLots, "protectPercent=",protectPercent, "addPercent=",AddPercent,"amount=",amount,"p=",p,"optLots=",optLots);
      }
   */   

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
   comment = "myma201:";
   double marginValue=MarketInfo(Symbol(),MODE_MARGINREQUIRED);
   Comment( comment+"一手保证金:"+DoubleToStr(marginValue,0));
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
   AddOrder(MAGICMA, AddRate, TkRate*StopLoss, 0.1, LimitRate,comment+"加仓",ProtectPercent);

   //open position
   RefreshRates();
   //if(TimeCurrent() - Time[0] <  Period()*60 - 60) return(0);  
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
      t = GetOrder(MAGICMA, OP_SELLSTOP);
      //double angle = iCustom(NULL, 0, "MA_Angle", 97, 48, 2, 0, 0);
      lot = Lots;
      //lot= NormalizeDouble( Lots*(1 + AccountEquity()/10000), 1);
      if( t == -1 ){
               /*
               if( KFilter > 0 && getHistoryOrder(MAGICMA) > 0){
                   if( TimeCurrent() - dtime3 > 80)
                   {
                     dtime3 = TimeCurrent();
                     Print("myma97: skip the singal since we just close an order op=",op);
                   } 
                   return 0;
               }
               */
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
   double p;
     
   for( int i = 2; i >= 0; i--)
   {
      p = iMA(Symbol(),0,pd,0,MODE_SMA,PRICE_CLOSE, i); 
      //double t = Open[i];
      //if( t < Close[i]) t = Close[i];
      //if( High[i] - t > factor*MathAbs(Open[i] - Close[i])) break;
      if(Close[i] <= p - SignalSpace/2) break;
      //test if(Close[i+1] <= p ) break;
      //if(Close[i] < p + 0.1) break;
   }
   if( i == -1)
   { 
     if(Low[SignalOffset] < p && Close[0] > p + SignalSpace)
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
         if( TimeHour(TimeCurrent()) == 11 &&  TimeCurrent() - ptime2 >= 30)
         {
            ptime2 = TimeCurrent();
            Print("isUp---true---------i=",i,"ma=",p,"close=",Close[0],"close5=",Close[5]);
         }
         //*/
         return(true);
     }    
   }
   for( i = SignalOffset; i >= 0; i--)
   {
      p = iMA(Symbol(),0,pd,0,MODE_SMA,PRICE_CLOSE, i); 
      //double t = Open[i];
      //if( t < Close[i]) t = Close[i];
      //if( High[i] - t > factor*MathAbs(Open[i] - Close[i])) break;
      if(Close[i] <= p ) break;
      //test if(Close[i+1] <= p ) break;
      //if(Close[i] < p + 0.1) break;
   }
   if( i == -1 && Close[0] > p + SignalSpace) return(True);
   /*
   if( TimeHour(TimeCurrent()) == 11 && TimeCurrent() - ptime1 >= 30)
   {
      ptime1 = TimeCurrent();
      Print("isUp----------------i=",i,"ma=",p,"close=",Close[0],"close5=",Close[5]);
   }
   //*/
   return(false);
}

bool isDown(int pd)
{
   double p;

   for( int i = 2; i >= 0; i--)
   {
      p = iMA(NULL,0,pd,0,MODE_SMA,PRICE_CLOSE, i);      
      if(Close[i] >= p + SignalSpace/2 ) break;
      //test if(Close[i+1] >= p ) break;
      //if(Close[i] > p - 0.1) break;
   }
   if( i == -1)
   {
     if(High[SignalOffset] > p && Close[0] < p - SignalSpace)
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
         if( TimeHour(TimeCurrent()) == 18 &&  TimeCurrent() - dtime2 >= 30)
         {
            dtime2 = TimeCurrent();
            Print("isDown---true---------i=",i,"ma=",p,"close=",Close[0],"close5=",Close[5]);
         }
         //*/
         return(true);
      }
   }
   for( int j = SignalOffset; j >= 0; j--)
   {
      p = iMA(Symbol(),0,pd,0,MODE_SMA,PRICE_CLOSE, j); 
      //double t = Open[i];
      //if( t < Close[i]) t = Close[i];
      //if( High[i] - t > factor*MathAbs(Open[i] - Close[i])) break;
      if(Close[j] >= p ) break;
      //test if(Close[i+1] <= p ) break;
      //if(Close[i] < p + 0.1) break;
   }
   /*
   if( TimeHour(TimeCurrent()) == 18 &&  TimeCurrent() - dtime1 >= 30)
   {
      dtime1 = TimeCurrent();
      Print("isDown----------------i=",i,"j=",j,"ma=",p,"close=",Close[0],"close5=",Close[5]);
   }
   //*/
   if( j == -1 && Close[0] < p - SignalSpace)
   {
       /*
         if( TimeHour(TimeCurrent()) == 18 &&  TimeCurrent() - dtime5 >= 30)
         {
            dtime5 = TimeCurrent();
            Print("isDown---true2---------j=",j,"ma=",p,"close=",Close[0],"close5=",Close[5]);
         }
         //*/
       return(True);
   }
   return(false);
}

void AddOrder(int mag, double aAddRate, int aTakeProfit, double rate, double limit, string c="", double minPercent = 0.5, double thirdlots = 0, double maxLots = 0)
{
   int t, total;
   if( RunMode == 1) return;
   total = GetTotalOrders(mag, OP_SELL);
   if( total == 0 || total >= 3) return;
   double lots = AddMaxLots(minPercent);
   if( lots <= 0) return;
   if( c== "") c = "Add ";
   t = GetOrder(mag, OP_SELL);
   double tk = OrderTakeProfit();
   double sl = OrderStopLoss();
   double point = getOrderPoint(); 

   if( OrderProfit() < 0) return; 
   //if( checkAdd(mag, OrderType())) return; //已经下过加仓的挂单，就返回
   int t2 = OrderTicket();
   double coef = 1;

   double orderprofitperlot = MathAbs( iMA(Symbol(),0, AddMa, 0, MODE_SMA,PRICE_CLOSE, 1) - OrderOpenPrice());

  //Print("=====coef=",coef,"==OrderLots==",OrderLots(),"====",OrderProfit() / (OrderLots() * coef),"=====",AddRate * TakeProfit);
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
            /*
         if( TimeDay(TimeCurrent()) == 18 && TimeHour(TimeCurrent()) == 8 &&  TimeCurrent() - dtime2 >= 30)
         {
            dtime2 = TimeCurrent();
            Print("orderprofiltperlot=============",orderprofitperlot, "addpos=",OrderOpenPrice()+AddRate*aTakeProfit*point);
         }
         //*/
      if(orderprofitperlot > aAddRate * aTakeProfit && orderprofitperlot < (aAddRate+limit) * aTakeProfit )
      {
            if( OrderSelect(t, SELECT_BY_TICKET, MODE_TRADES) == FALSE){
             Print("AddOrder2 failed0: ",ErrorDescription(GetLastError()));
             return;
            }
            dt2 = TimeCurrent();
            Print(c, "Add2-1原单[",t,"][",OrderTicket(),"]:OrderType=",OrderType(),"OrderProfit=",OrderProfit(), "-",aAddRate,"-",lots,"tk=",tk,"sl=",sl,"price=",NormalizeDouble(Ask-(rate*aTakeProfit*point),Digits));
            if( OrderType() == OP_BUY) OrderSend(Symbol(),OP_BUY,lots, NormalizeDouble(Ask,Digits),50, sl, tk,c+"buylimit position",mag,0,Blue);
            else  OrderSend(Symbol(),OP_SELL,lots,NormalizeDouble(Bid,Digits),50, sl,tk,c+"selllimit position",mag,0,Red);
            Sleep(10000);
      }
    }
    }
}
  
// the end.