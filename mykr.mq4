//入场条件1：0KR的4小时信号入场，信号质量检查用趋势位置
//入场条件2：0KR的连续3个信号形成1-2-3组合，即1-2与2-3反向，且2-3幅度小于1-2的50%
//入场条件3：0KR为趋势方向，0KRSingle达到５根反向信号，且形成一段趋势（即这一段
//的波动达到一定值），则在第一个正向信号入场

#include<stdlib.mqh>
extern string version = "1.1";
extern double StopLoss = 92;
extern double TimeSL   = 64;
extern double MARange = 8;
extern double TR = 6;
extern double TkRate = 0.5;
extern double SlRate = 1.3;
extern double Lots =  0.1;
extern int    StopPeriod = 48;
extern bool   NotifyPhone = FALSE;
extern bool   macdCheck = FALSE;
extern int    KFilter = 24;     //very important to avoid swing loss!!! but need mixing with some more flexible strategy to avoid losing a big trend
extern int    KFilter2 = 2;
extern double KVol     = 0.0050;
extern double AddPercent = 0.2; //Add Plan trade lots percent
extern double AddRate = 0.2;   //Add Plan mark position
extern double LimitRate = 0.2;  //Add Plan trade position up limit
extern double  ProtectPercent = 1;
extern double  thirdLots = 8;  //2
extern double ATRTimeFrame=240;
extern double ATRPeriod = 6;
extern double ATRRange = 0.003;
extern string skiptime1 = "2013.12.18,2014.01.29,2014.03.19,2014.04.30,2014.06.18";//非农和美联储决议 

/*
extern int    TrendK = 10;
extern double TrendRange = 10;
*/
#define MAGICMA  14052801 //trend
#define MAGICMB  14052802 //swing
datetime     cur = 0;
datetime pt, st, pt2,pt3,pt4;

int init()
{
         return(0);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int start()
  {
   string ss[2];
   ss[0] = "买"; ss[1]="卖";
   string comment;
   comment = "mkr:加仓";
   //ClosePendingOrder(MAGICMA);
   //AddOrder2(MAGICMA, AddRate, TkRate*StopLoss, 0, LimitRate,comment,ProtectPercent,thirdLots);
   RefreshRates();
   if( TimeCurrent() - Time[0] < Period()*60 - 40 ) return(0); //K线收盘
   //if( TimeCurrent() - cur < Period()*60 - 40 ) return(0);       //隔1小时，但可能不是在收盘点，因为测试数据没有
   //cur = TimeCurrent();
   if( skiptime(skiptime1)){
      return(0);
   }

   int op = -1;
   double objPrice = iCustom(Symbol(), 0, "0KR", 300, 240, 0, 0); 
   double atr = iATR(Symbol(), 0, ATRPeriod, 0);
   //double macd = iMACD(Symbol(), Period(), 24, 52, 9, PRICE_CLOSE, MODE_MAIN,0 );
   //if( macd > 0 && objPrice == 1) op = 0;
   //else if( macd < 0 && objPrice == -1) op = 1;
   if( objPrice > 0 && objPrice != EMPTY_VALUE) op = 0;
   else if( objPrice < 0) op = 1;
   //if( op != -1 )// && adx < ADXLevel)
   {      
      datetime now = TimeCurrent();
      if( now - pt > 60 )
      {  
         pt = now;
         //if( TimeDay(Time[0]) == 21)
         Print("*****objprice=",objPrice,"op=",op,"close[0]=",Close[0],"]@",TimeToStr(Time[0]));
      }
   }
   int t = GetOrder(MAGICMA, OP_SELL);
   //时间平仓
   if( t > 0 && OrderProfit() < 0)
   {
      if( CurTime() - OrderOpenTime() > TimeSL * Period() * 60)// || TimeDay(CurTime()) != TimeDay(OrderOpenTime()) )
      {
         //op = 1 - OrderType();
         //CloseOrder(t, op);
         //return 0;
      }
   }
   //K线大波动平仓
   if( t > 0 && isBigK()){
         Print("mkr:大波动出现，平仓[原"+ss[OrderType()]+"单"+t+"]");
         CloseOrder(t, 1-OrderType());
   }
   if( op != -1 && atr < ATRRange){
         if( now - pt4 > 60){
            pt4 = now;
            Print("mkr:信号出现，但判断为盘整 atr=",atr);
         }
         return(0);
   }
   if( op != -1 && !isBigTrend())// && t == -1) 
   {
      //Print(High[iHighest(Symbol(), 0, MODE_HIGH, TrendK,0)] -Low[iLowest(Symbol(), 0, MODE_LOW, TrendK, 0)]);
      double lot = Lots;
      lot= NormalizeDouble( Lots*(1 + AccountEquity()/10000), 1);
      int mag = MAGICMA;
      double a = myATR(ATRTimeFrame, 0, ATRPeriod);
      int sl = StopLoss; // MathAbs(Close[0] - objPrice) / Point / 10 + StopLoss;
      int tk = StopLoss; 
      /*
            //判断是否震荡行情，如果是，则信号反向
      if( adx < ADXLevel){
          op = 1 - op;
          mag = MAGICMB;
          tk = sl;
      }
      else
          sl *= SlRate;
      */
      string s[2];
      s[0] = "atr="+atr;
      s[1] = s[0];
      string m = Symbol()+Period()+s[op]+DoubleToStr(objPrice, 4)+"价格"+Bid;
      if( NotifyPhone && CurTime() - st > 60){
            st = CurTime();
            SendNotification(m);
            Print(m);
      }

      if( t == -1) t = GetOrder(MAGICMB, OP_SELL);
      if( t == -1 ){
               if( now - pt2 > 60)
               {
                  pt2 = now;
                  //Print("sl=",sl,"TkRate=",r,"a=",a,"tk=",tk);
                  if( getHistoryOrder(MAGICMA) > 0 || getHistoryOrder(MAGICMB) > 0){ if( OrderType() == op) return 0;}
                  comment = "mkr:"+s[op]+"新"+ss[op]+"单";
                  OpenOrder(op, lot, sl, tk, mag, comment);
                }
         }
         else{
               if( now - pt3 > 60)
               {
                  pt3 = now;
                  //Print("t=",t,"sl=",sl,"TkRate=",r,"a=",a,"tk=",tk);
                  comment = "mkr:"+s[op]+"反手开"+ss[op]+"单"+"[原"+ss[OrderType()]+"单"+t+"]";
                  if( GetOrder(MAGICMA, OP_SELL) != -1) OpenReverseOrder(t, op, lot, sl, tk, MAGICMA,comment);
                  else OpenReverseOrder(t, op, lot, sl, tk, MAGICMB,comment);
                }
         }
      
      
   }
   return(0);
  }
  
bool isBigK()
{
   //ToDo: KVol是一个ATR平均值，即出现一个幅度大幅超过平均波动的K线则认为趋势信号不准确
   if( MathAbs(High[0] - Low[0]) > KVol){ 
      return(true); 
   }
   return(false);
}
  
bool isBigTrend()
{
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
      if( Ask > 800) point = 0.1;  //gold
      
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
           if( StringFind(TerminalName(), "FXCM") >= 0 && Ask > 800) coef = 100; //Lots = Lots * 100; 
           if( StringFind(TerminalName(), "FOREX") >= 0 && Ask > 800) coef = 10; //Lots = Lots * 100;
           if( isBigK()){ Print("OpenOrder: 信号的K线幅度太大不能用来开仓"); return; }
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
           Print(c,"==point=",point,"==",Ask,"=lots=",aLots,"==op==",op,"==price=",aprice,"=sl=",sl,"==tk=",tk);

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
//反向信号出现，可能是swing反转，可能是回调，反转时反手，回调时加仓
void OpenReverseOrder(int ticket, int op, double aLots, int aStopLoss, int aTakeProfit, int mag,string c="")
{
      if( OrderSelect(ticket,SELECT_BY_TICKET, MODE_TRADES)==false )return;
      int coef = 1;
      if( StringFind(TerminalName(), "FXCM") >= 0 && Ask > 800) coef = 100; //Lots = Lots * 100; 
      if( StringFind(TerminalName(), "FOREX") >= 0 && Ask > 800) coef = 10; //Lots = Lots * 100;
      double lots = OrderLots()/coef;
      double opt = OrderProfit();
      int n;
      //过滤太近的信号
      if( CurTime() - OrderOpenTime() < KFilter2 * Period() * 60) return;
      //判断走势来区分反转和回调
      if( OrderProfit() > aTakeProfit / 3.0){
         //回调
         Print("====mkr-OpenReverseOrder 判断为回调ticket=",ticket,"op=",op,"aLots=",aLots,"==ordertk=",OrderTakeProfit(),"==aTk=",aTakeProfit,"==op=",op);
         return;
      }
      n = CloseOrder(ticket, op);
      
      if( n == 1 && opt < 0 ){
         lots = 2 * lots;
         double max = AddMaxLots(ProtectPercent);
         if( lots > max) lots = max;
      }
      else lots = aLots;
      Print("====mkr-OpenReverseOrder ticket=",ticket,"op=",op,"aLots=",aLots,"==lots=",lots,"==n=",n,"==op=",op);
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
   double p = Ask;
   if( Ask > 800) p = Ask / 1000;
   double coef = 1;
   double curLots = symbolLots(OP_SELLSTOP);
   if( StringFind(TerminalName(), "FXCM") >= 0 && Ask > 800){
      coef = 0.01; //FXCM 1gold = 0.01 10 = 0.1 
   }
   else{
      if( StringFind(TerminalName(), "FOREX") >= 0 && Ask > 800){
         coef = 0.1; //Forex 1gold = 0.1 10 = 1 
      }
   }
   if( AccountEquity() > 5000){ protectPercent /= 2;}
   
   double amount = AccountFreeMargin() - curLots * coef * Ask * (1 + protectPercent);
   amount = amount*AddPercent;
   /*
      if( TimeCurrent() - dt2 > 1500)
      {
         dt2 = TimeCurrent();
         double a = (1 + protectPercent) * Ask * 0.1;
         Print("free=",AccountFreeMargin(),"a=",a,"curLots=",curLots, "protectPercent=",protectPercent, "protectPercent=",protectPercent,"amount=",amount);
      }
     */
   if( amount < 0 || amount < (1 + protectPercent) * Ask * 0.1 ) return(0);
   double optLots = MathCeil( amount /  (p * 100)  ) / 10;
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
   double coef = 10;
   if( StringFind(TerminalName(), "FXCM") >= 0 && Ask > 800){
      coef = 0.1; //FXCM 1gold = 0.01 10 = 0.1 
      lots *= 100;
   }
   else{
      if( StringFind(TerminalName(), "FOREX") >= 0 && Ask > 800){
         coef = 1; //FXCM 1gold = 0.01 10 = 0.1 
         lots *= 10;
      }
   }
   if( c== "") c = "Add ";
   t = GetOrder(mag, OP_SELL);
   double tk = OrderTakeProfit();
   double point = getOrderPoint(); 
   //Print("=====coef=",coef,"==OrderLots==",OrderLots(),"====",OrderProfit() / (OrderLots() * coef),"=====",aAddRate * aTakeProfit);
   { 
   if( total < 2)  // 第一次加仓
   {
      RefreshRates();
      if( OrderSelect(t, SELECT_BY_TICKET, MODE_TRADES) == FALSE){
       Print("AddOrder2 failed0: ",ErrorDescription(ErrorDescription(GetLastError())));
       return;
      }
      /*
      if( TimeCurrent() - dt2 > 600)
      {
         dt2 = TimeCurrent();
         Print("*************debug: open=",OrderOpenPrice(),"ask=",Ask,"bid=",Bid,"orderprofit=",OrderProfit(),"profit=",OrderProfit() / (OrderLots() * coef));
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
               if( OrderSend(Symbol(),OP_BUY,lots, NormalizeDouble(Ask,Digits),50,NormalizeDouble(OrderStopLoss(),Digits), tk,c+"buylimit position",mag,0,Blue) == -1)
               { Print("Send order error: ", ErrorDescription(GetLastError()));
               }
            }
            else{
               if(  OrderSend(Symbol(),OP_SELL,lots,NormalizeDouble(Bid,Digits),50,NormalizeDouble(OrderStopLoss(),Digits),tk,c+"selllimit position",mag,0,Red) == -1)
                           { Print("Send order error: ", ErrorDescription(GetLastError()));
                           }
            }
            Sleep(10000);
      }
    }
    else
    {
     double mkr = iMA(Symbol(), 0, 55 , 0, MODE_SMA, PRICE_CLOSE, 0);
     if( thirdlots > 0 && MathAbs(Close[0] - mkr) < MARange)
     //if( thirdlots > 0)
      {
         if( getHistoryOrder(mag) > 0) return;
         RefreshRates();
         if( OrderSelect(t, SELECT_BY_TICKET, MODE_TRADES) == FALSE){
          Print("AddOrder2 failed2: ",ErrorDescription(ErrorDescription(GetLastError())));
          return;
         }
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
      max = MathAbs(iHigh(Symbol(), t, i) - iLow(Symbol(), t, i));
      c1 = MathAbs(iHigh(Symbol(), t, i) - iClose(Symbol(), t, i+1));
      if( max < c1) max = c1;
      c1 = MathAbs(iLow(Symbol(), t, i) - iClose(Symbol(), t, i+1));
      if( max < c1) max = c1;
      tmax += max; 
   }
   return tmax;
}

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

// the end.