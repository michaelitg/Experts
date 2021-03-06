//+------------------------------------------------------------------+
//| MACD and Break Line                                              +
//+------------------------------------------------------------------+
#property copyright   "2015 (c) michael"
#property link        "michaelitg@outlook.com"

#include <7common.mqh>

input double TakeProfit    = 140;
input double StopLoss      = 100;
//This is for short trend, for more fast trend, use 100/200 to catch up the long fast trend
input double Lots          = 0.1;
input int    maxOrders     = 1;
extern int   addPos        = 5;
extern int   openextra     = 0;
extern double openextrapos = 0.1;
input double factor1       = 1.5;
input double factor2       = 2;
extern int    opennow       = -1;
extern int    tradedir      = -1;
extern double    MACDScale = 1;
extern double    MACDOpenLevel = 9;

int       FastMAPeriod=60;
int       SlowMAPeriod=130;
int       SignalMAPeriod=45;

//------
#define MAGICMA  20151112
string EAName = "mymacd-H1-r0.11";
//must be global to use continually
datetime     cur = 0;
datetime     pt = 0;

void init()
{

   FastMAPeriod=60*MACDScale;
   SlowMAPeriod=130*MACDScale;
   SignalMAPeriod=45*MACDScale;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick(void)
  {
   //if( TimeCurrent() - Time[0] < Period()*60 - 30 ) return; //K线收盘
   if( TimeCurrent() - cur < Period()*60 - 30 ) return;       //隔1小时，但可能不是在收盘点，因为测试数据没有
   cur = TimeCurrent();
   
   double sig;
   //for( int k = 0; k <= 10; k++)
   int wait, k = 6;
   {
      sig = iCustom(Symbol(), 0, "MACD_2Line", FastMAPeriod, SlowMAPeriod, SignalMAPeriod, MACDOpenLevel, 4, k);
      //if( sig != EMPTY_VALUE && sig >= 0 ) break;
   }
   int op = -1;
   if( sig != EMPTY_VALUE && sig >= 0){
      if( sig == 0 || sig == 2*Point*100) op = 0;
      else op = 1;
   }
   
   if( sig >= 0 && TimeCurrent() - pt > 60){
      Print("op=",op,"k=",k,"sig=",sig,"@",TimeToStr(Time[0]));
      pt = TimeCurrent();
   }
   
   double lots = Lots;
   double tr = iCustom(Symbol(), 0, "MACD_2Line", FastMAPeriod, SlowMAPeriod, SignalMAPeriod, MACDOpenLevel, 5, 0);
   if( tr != 0)
   {
      if( tr > 0 && op == OP_BUY) lots *= 2;
      if( tr < 0 && op == OP_SELL) lots *= 2;
   }
   int mag = MAGICMA;
   if( opennow != -1 && GetTotalOrders(mag, OP_SELL) == 0)
   {
      op = opennow;
      opennow = -1;
   }
   if( tradedir >= 0){
      if( op != tradedir) op = -1;      
   }
   //处理已有仓位
   double factor = 1;
   if( getHistoryOrder( mag, 4)<0 ) wait = 0;
   else wait = 1;//如果有单子刚刚平仓，则等待
   int t = GetLastOrder(mag, OP_SELL);
   if( t != -1 && wait == 0){
         //有反向信号，判断持仓是否应该平掉。如果平掉同时增大新仓的参数
         double tr2 = iCustom(Symbol(), 0, "MACD_2Line", FastMAPeriod, SlowMAPeriod, SignalMAPeriod, MACDOpenLevel, 5, 1);
         int tsig = -1;
         if( tr2 == 0 && tr > 0) tsig = 0;
         if( tr2 == 0 && tr < 0) tsig = 1;
         //double b=iBands(Symbol(),0,bband,2,0,PRICE_CLOSE,MODE_MAIN,0);
         //if( OrderProfit() < 0 && ((OrderType() == OP_BUY && op == 1 && Ask < b) || (OrderType() == OP_SELL && op == 0 && Ask > b))){  //b is necessary
         if( OrderProfit() < 10 && ((OrderType() == OP_BUY && op == 1 ) || (OrderType() == OP_SELL && op == 0 )))
         {  
            CloseOrder2(mag+1, 4);
            CloseOrder2(mag-1, 4);
            CloseOrder(t, 1-OrderType());
            factor = factor1;
            Print("****************Close position by reverse signal op=",op,"tsig=",tsig,"tr=",tr,"tr2=",tr2,"*******@",TimeToStr(TimeCurrent()));
         }
         else //加仓
         {
            if((OrderType() == OP_BUY && tsig == 0) || (OrderType() == OP_SELL && tsig == 1)  )
            {
               if( GetTotalOrders(mag+1, OP_SELL) < 1)
               {
                  GetLastOrder(mag, OP_SELL);
                  double addp = NormalizeDouble(Ask, Digits); 
                  if( OrderType() == OP_SELL) addp = NormalizeDouble(Bid, Digits); 
                  if( OrderSend(Symbol(), OrderType(), lots*addPos, addp, 50, OrderStopLoss(), OrderTakeProfit(), "Add", mag+1) == -1)
                  { Print("Add position Error = ",ErrorDescription(GetLastError()));} //add position
                  else
                    Print("****************Add position by trend signal tsig=",tsig,"tr=",tr,"tr2=",tr2,"*******@",TimeToStr(TimeCurrent()));
               }
            }
         }
   }

   //开新仓
   if( op != -1 && wait == 0)
   {
      string s[2];
      s[0] = EAName+"逢低买入";
      s[1] = EAName+"逢高卖出";
      if( GetTotalOrders(mag, OP_SELL) < maxOrders)
      {
            t = GetLastOrder(mag, OP_SELL);
            if( t != -1 && maxOrders > 1 ){  //多仓位系统，暂时放着
               //if( checkProfitOrders(mag) == False) CloseOrder2(mag, 4); //CloseOrder(t, op);
               //add position
               //OpenOrder(op, lots, -StopLoss, TakeProfit, mag, s[op],0);
            }
            else{
               Print("****************Open position now*******@",TimeToStr(TimeCurrent()));
               t = getHistoryOrder(mag, -1); //获取最后一个平仓的单子
               if( t == -1 || (t >= 0 && (OrderLots() <= Lots || CurTime() - OrderCloseTime() > 48 * Period() * 60 ))) //如果最后平仓的是大幅亏损的单子，则必须冷静一段时间
               {
                  if( t >= 0 && MathAbs(OrderClosePrice()- OrderStopLoss()) < 20*Point && op != OrderType() && CurTime() - OrderCloseTime() < 48 * 4 * Period() * 60) 
                  //如果是止损单，而且相隔不超过2天，则加大新仓参数
                           factor = factor2;
                  int hp = checkHistoryOrder(mag);
                  if( MathAbs(hp) >= 3 && MathAbs(hp) < 5){   //如果连续亏损超过3次，但没有到5次，说明行情进入了震荡，则把信号反过来用，同时加大参数
                     if( op == 0) op = 1; else op = 0; 
                     factor = factor2;}
                  if( MathAbs(hp) < 5 || getHistoryOrder( mag, 48*4)< 0 ) //如果连续亏损超过5次，则说明震荡还是趋势看不清楚。也必须冷静一段时间
                  {
                     double tk = TakeProfit*factor;
                     OpenOrder(op, lots*factor, -StopLoss, tk, mag, s[op],openextra, 0.1); //new position
                  }
                  else
                     Print("****************Too much loss, calm down*******@",TimeToStr(TimeCurrent()));
               }
               else 
                  Print("****************A big last loss, calm down*******@",TimeToStr(TimeCurrent()));
            }
      }
      //Print(s[op],"op=",op,"sig=",sig,"lots=",lots);
   }
   
}
