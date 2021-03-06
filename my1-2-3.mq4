#include<stdlib.mqh>
#include "PanelDialog.mqh"
#include <common.mqh>
#include <my1-2-3-ma.mqh>
#include <my1-2-3-break.mqh>
#include <my1-2-3-k.mqh>
#include <my1-2-3-ma97.mqh>

CPanelDialog ExtDialog;
string version = "1.303 22/04/2021";

int init()
{
//--- create application dialog
   string title = "my1-2-3 v" + version;
   if(!ExtDialog.Create(0, title,0,0,450,600,700))
     return(INIT_FAILED);
//--- run application
   if(!ExtDialog.Run())
     return(INIT_FAILED);
     return(0);
}
void OnDeinit(const int reason)
  {
//--- destroy application dialog
   ExtDialog.Destroy(reason);
  }
  
  void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
  {
   ExtDialog.ChartEvent(id,lparam,dparam,sparam);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int start()
  {
   int sl, tp;
   string comment = "my1-2-3:";
   //Comment("KTrademode=",KTradeMode, "Bid=",Bid,"command=",command,"Eq=",TP_Equity);
   //if( Period() != RunPeriod ){
   //    ExtDialog.UpdateLabel("Run Period is not correct!");
   //    return(0);
   //}
   double Max_Equity = AccountBalance() * 1.33;
   double Min_Equity = AccountBalance() / 3 * 2;
   if(SL_Equity < Min_Equity) SL_Equity = Min_Equity;
   if(TP_Equity < Max_Equity) TP_Equity = Max_Equity;
   string v = "KTrademode="+KTradeMode+" TradeMode="+TradeMode+" BollerTrade="+BollerTrade+" ma97TradeEnabled="+ma97TradeEnabled+" breakTradeEnabled="+breakTradeEnabled;
   Comment("command=",command,"TP/SL/Cur=",TP_Equity,"/",SL_Equity,"/", AccountEquity(),"Hour=",TimeHour(TimeCurrent())," Auto TP/SL Equity Close Enabled.\n",v);
   //calculate SL of total equity

   sl = StopLoss; // MathAbs(Close[0] - objPrice) / Point / 10 + StopLoss;
   tp = MathCeil((double)sl * TkRate);
   int op = -1;
   int mag = MAGICMA+Period()+MagSpecial;

   if( EnableDayClose == 1 && TimeHour(TimeCurrent()) == 20 && TimeMinute(TimeCurrent()) == 50)
   {
      Print("my1-2-3: Day Close enabled and is executing at ",TimeToStr(TimeCurrent()),"------------------------------------------------------");
      command = 1;
   }
   if( command == 0)  //print signal in system log
   {
      dtime1 = dtime2 = dtime4 = dtime5 = 0;
      getBreakSignal();
      command = -1;
      ExtDialog.UpdateLabel("Signal log printed at "+TimeToStr(TimeCurrent()));
      Print("-------------Log printed.----------------------");
   }
   else if( command == 1 || AccountEquity() >= TP_Equity || AccountEquity() <= SL_Equity)
   {
      Print("------------Equity or day close-----------------------", AccountEquity());
      double profit = CloseAllOrders();
      command = -1;
      ExtDialog.UpdateLabel("All orders closed, total profit="+DoubleToStr(profit,0)+".  AccountEquity="+ AccountEquity());
   }
   else if( command == 2)
   {   
      comment = "my123(Period-"+Period()+")"+" add position"+ss[TradeDirection]+"order";
      OpenOrder(TradeDirection, Lots, sl, tp, mag, comment);
      ExtDialog.UpdateLabel("Add position of "+Symbol()+" lots="+Lots+".");
      command = -1;
   }
   else if( command == 3)
   {
      comment = "123("+Period()+")"+" add limit "+ss[TradeDirection]+"order";
      OpenKOrder(TradeDirection, Lots, sl, tp, mag, comment);
      ExtDialog.UpdateLabel("Add limit position of "+Symbol()+" lots="+Lots+".");
      command = -1;
   }
   if( KTradeMode >= 0) kTrade(mag);
   
   RefreshRates(); 
   if( TimeCurrent() - mainTimer < 60 || DisableAll == 1) return 0;
   mainTimer = TimeCurrent();
      
   mag = MAGICMB+Period()+MagSpecial;
   bollerTrade(mag);
   
   mag = MAGICMA+Period()+MagSpecial;
   breakTrade(mag);
   
   mag = MAGICMC+Period()+MagSpecial;
   ma97Trade(mag);
   return(0);
  }


//检查是否有在n根K线内平仓的单子
int getHistoryOrder(int mag, int aKFilter, int op)
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
                         if( OrderType() == op) // && OrderProfit() < 0) 
                           return(OrderTicket());
                      }
                  }
               }
   }
   return(-1);
}

void OpenOrder(int op, double aLots, int aStopLoss, int aTakeProfit, int mag, string c="",string extrac="")
{
           double point = getPoint();
           double aprice, sl, tk;
           if( c == "") c = "myea openorder";
           RefreshRates();
           double d2 = ExtDialog.GetTakeProfit();
           if( d2 > 0) aTakeProfit = d2;
           if( op == OP_BUY)
           {     
                  aprice = Ask;
                  sl = Ask - aStopLoss * point;
                  if( aTakeProfit > 0)  tk = Ask + aTakeProfit * point;
                  else tk = 0;
           }
           if( op == OP_SELL)
           {
                  aprice = Bid;
                  sl = Bid + aStopLoss * point;
                  if( aTakeProfit > 0) tk = Bid - aTakeProfit * point;
                  else tk = 0;
           }
           double onelot = 1;
           if( aLots >= 4) onelot = 2;
           if( Ask < 500){
             onelot *= 0.1;  //AUD
             aLots *= 0.1;
           }
           if(onelot > aLots) onelot = aLots;
           double lot = 0;
           while( lot < aLots)
           {
                  if(OrderSend(Symbol(), op, onelot, NormalizeDouble(aprice, Digits), 500, sl, tk, c, mag) == -1)
                  { Print("myea Error = ",ErrorDescription(GetLastError())); }
                  Sleep(1000);
                  lot += onelot;
           }            
           Print("Manual OpenOrder Total:",c,extrac,"onelot=",onelot,"==",aprice,"=lots=",aLots,"==op==",op,"=sl=",sl,"==tk",tk);

}

void OpenKOrder(int op, double aLots, int aStopLoss, int aTakeProfit, int mag, string c="",string extrac="")
{
           double point = getPoint();
           double aprice, sl, tk;
           if( c == "") c = "myea openorder";
           RefreshRates();
           double d1 = ExtDialog.GetOpenPrice();
           double d2 = ExtDialog.GetTakeProfit();
           if( d1 > 0) aprice = d1;
           else aprice = Close[1];
           if( d2 > 0) aTakeProfit = d2;
           if(op == OP_BUY)
           {     
                  //op = OP_BUY;
                  sl = aprice - aStopLoss * point;
                  if( aTakeProfit > 0)  tk = aprice + aTakeProfit * point;
                  else tk = 0;
                  if( Ask != aprice){
                     if( Ask < aprice) op += 4;
                     else op += 2;
                  }
           }
           else
           {
                  //op = OP_SELL;
                  sl = aprice + aStopLoss * point;
                  if( aTakeProfit > 0) tk = aprice - aTakeProfit * point;
                  else tk = 0;
                  if( Bid != aprice){
                     if( Bid > aprice) op += 4;
                     else op += 2;
                  }
           }
           double onelot = 1;
           if( aLots >= 4) onelot = 2;
           if( Ask < 500){
             onelot *= 0.1;  //AUD
             aLots *= 0.1;
           }
           if(onelot > aLots) onelot = aLots;
           double lot = 0;
           while( lot < aLots)
           {
                  //if(OrderSend(Symbol(), op, onelot, NormalizeDouble(aprice, Digits), 500, sl, tk, c, mag) == -1)
                  //{ int e = GetLastError();Print("myea Error = ",e,ErrorDescription(e));Print("OpenKOrder error:",c,extrac,"onelot=",onelot,"==",aprice,"=lots=",aLots,"==op=",op,"=sl=",sl,"==tk",tk,"Bid=",Bid,"Ask=",Ask); }
                  //Sleep(1000);
                  lot += onelot;
           }            
           Print("TEST ONLY OpenKOrder total:",c,extrac,"onelot=",onelot,"==",aprice,"=lots=",aLots,"==op==",op,"=sl=",sl,"==tk",tk);

}


double getTotalOrderLots(int mag, int oType)
{
   double t = 0;
   for(int i=0;i<OrdersTotal();i++)
     {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==false) break;
      if( (mag != 0 && OrderMagicNumber()!= mag) || OrderSymbol()!=Symbol()) continue;
      //---- check order type 
      if( OrderType() == oType) t += OrderLots();
     }
     return(t);
}


void OpenReverseOrder(int ticket, int op, double aLots, int aStopLoss, int aTakeProfit, int mag,string c="")
{
      if( OrderSelect(ticket,SELECT_BY_TICKET, MODE_TRADES)==false )return;
      double lots = OrderLots();
      double opt = OrderProfit();
      double n = CloseOrder(ticket, op);
      //Print("====myea-OpenReverseOrder","==lots=",lots,"==n=",n,"==op=",op);
      if( n > 0 )
      {
         double pp = lots;
         if( pp < 1) pp *= 10;
         if( opt / pp < -ReverseSpace ){
            if( lots < 1) lots = 2 * n * 10;
            else lots = 2*n;
            if( lots > MaxLots) lots = MaxLots;
         }
         else lots = aLots;
         OpenOrder(op, lots, aStopLoss, aTakeProfit, mag, c,"[origin "+ticket+"]");
      }
}

//-------------------------------checked ok 18/03/2021--------------------------------------------
double CloseAllOrders()
  {
   //disable all trade if closed all
   DisableAll = 1;

   bool   result;
   double price,totalprofit = 0;
   int    cmd,error;
   Print("==================close all orders!=================");
   int tickets[1000];
   int j = 0;
   for(int i = 0; i < OrdersTotal(); i++)
   {
     if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES) )
     {
      cmd=OrderType();
      if(cmd==OP_BUY || cmd==OP_SELL)
      {
         tickets[j] = OrderTicket();
         j++;
      }
     }
   }  
   for(i = 0; i < j; i++)
   {
     Print("close-----:",i,"/", j);
     if(OrderSelect(tickets[i],SELECT_BY_TICKET,MODE_TRADES))
     {
      OrderPrint();
      int    digits=MarketInfo(OrderSymbol(),MODE_DIGITS);
      double point = getOrderPoint();
      cmd=OrderType();
      
      //---- first order is buy or sell
      if(cmd==OP_BUY || cmd==OP_SELL)
        {
            if(cmd==OP_BUY) price=OrderOpenPrice() + OrderProfit()/(OrderLots()*10)*point;
            else            price=OrderOpenPrice() - OrderProfit()/(OrderLots()*10)*point;
            price = NormalizeDouble(price, digits );
            Print("OpenPrice=", OrderOpenPrice(), " ClosePrice=",price," Profit=",OrderProfit());
            totalprofit += OrderProfit();
            result=OrderClose(OrderTicket(),OrderLots(),price,50,CLR_NONE);
            if(result!=TRUE) { error=GetLastError(); Print("LastError = ",error); }
            else error=0;
        }
     }
     else Print( "Error when order select ", GetLastError());
   }

   return(totalprofit);
  }
//-----------------------------------checked ok end 18/03/2021--------------------------------------------------

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


string changeShortName(string name)
{
   int m = StringLen(name) - 5;
   if( m < 0) m = 0;
   string n = StringSubstr(name, m);
   string lname[2] = {"Horizontal Line ",""};
   string sname[2] = {"HL","TL"};
   for( int i = 0; i < 2; i++)
      if(StringFind(name, lname[i]) >= 0) return sname[i]+n;
   return n;
}


// the end.