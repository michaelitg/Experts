string EAName = "7biyudao-M15-2.0";
//碧玉刀，刀本身并没有多大的出色之处，出色的是用刀的人做事的方式。
//正如交易，用什么指标和技术手段并不重要，重要的是把这些东西组合起来的人，
//他如何思考，如何用正确的方式做事，从而使自己无论身处何种市场，都能游刃有余。
//这个EA必须由熟练掌握道氏理论的人运用，找到中期趋势，然后顺应中期趋势，
//在短期震荡的拐点入场，复合仓，止盈使用布林宽度
//要耐心,最好的机会是下跌->整理->上涨,即有一段整理后趋势开始明朗后使用
//切忌贪婪,在趋势不明朗的时候使用,试图猜顶摸底,放弃头尾,只吃鱼身,已经够了
//更多的改进是在仓位管理
//需要的指标：WPR

#include <7common.mqh>

extern string commentrend="0:Stop 1:buy 2:Sell for M15"; //0:停止 1:逢低吸纳 2:逢高卖出";
extern int    trend = 2;
extern double Lots = 0.1;
extern double StopLoss = 130;
extern double TkRate = 1.4;
extern double maxTakeProfit = 400;
extern string skiptime1 = "2013.12.18,2014.01.29,2014.03.19,2014.04.30,2014.06.18";//非农和美联储决议 
extern int    orderPeriod = 3800;
extern int    maxOrders = 6;
extern int    myKFilter = 4;
extern int    BPeriod = 20; // Bollinger period
extern int    Deviation = 2; // Bollinger deviation
extern int    wpr_Period1    = 12;  
extern int    wpr_Period2    = 48; 
extern int    wpr_tPeriod1    = 12;  
extern int    wpr_tPeriod2    = 48; 
extern int    bbf = 12;
extern int    tPeriod = 24;
extern double aa1V = 25;

double TakeProfit = 0;
#define MAGICMA  101140630
int rtrend = 0;
datetime dp = 0, dp2 = 0;

double avg_wpr(int timeframe, int start, int calPeriod)
{
   int i;
   double a = 0;
   for( i = start; i < start + calPeriod; i++)
   {
      a = a + iCustom(Symbol(),timeframe,"WPR", wpr_Period1, wpr_Period2, false, 1, i);
   }
   return(a / calPeriod);
}
double avg_wpr2(int timeframe, int start, int calPeriod)
{
   int i;
   double a = 0;
   for( i = start; i < start + calPeriod; i++)
   {
      a = a + iCustom(Symbol(),timeframe,"WPR", wpr_tPeriod1, wpr_tPeriod2, false, 1, i);
   }
   return(a / calPeriod);
}
bool checksell()
{
   if( getHistoryOrder(MAGICMA, myKFilter) > 0) return false;   
   return true;
}


bool checkbuy()
{
   if( getHistoryOrder(MAGICMA, myKFilter) > 0) return false; 
   /*
   if( CurTime() - dp > 60)
   {
      dp = CurTime();   
      Print(OrderTicket(), "===",OrderOpenPrice(),"==", OrderOpenPrice() - Bid, "==",StopLoss*getPoint());   
   }
   */
   return true;
}

int start()
  {
   int mag = MAGICMA;
   if(TimeCurrent() - Time[0] <  Period()*60 - 60) return(0);
   if (ObjectFind("BKGR") < 0) {
      ObjectCreate("BKGR", OBJ_LABEL, 0, 0, 0);
      ObjectSetText("BKGR", "g", 110, "Webdings", LightSlateGray);
      ObjectSet("BKGR", OBJPROP_CORNER, 0);
      ObjectSet("BKGR", OBJPROP_BACK, TRUE);
      ObjectSet("BKGR", OBJPROP_XDISTANCE, 5);
      ObjectSet("BKGR", OBJPROP_YDISTANCE, 15);
   }
   double bup=iBands(Symbol(),0,BPeriod,Deviation,0,PRICE_OPEN,MODE_UPPER,0);
   double bdn=iBands(Symbol(),0,BPeriod,Deviation,0,PRICE_OPEN,MODE_LOWER,0);
   TakeProfit = MathCeil((bup - bdn) / getPoint() * TkRate );
   string c[3] = {"停止交易","逢低买入","逢高卖出"};
   Comment(EAName,"\n",c[trend],"\n","tp=",TakeProfit);
   if( skiptime(skiptime1)) return(0);
 
   int a = getHistoryOrder(mag, 1);

   if ( a > 0 &&  TimeCurrent() - dp2 > 1800)
   {
      dp2 = TimeCurrent();
      Print("******************get history order:",a);
      double a_time = OrderOpenTime();
      if( OrderSelect(a+1, SELECT_BY_TICKET))
      {
         if( OrderProfit() > 0 && MathAbs(OrderOpenTime() - a_time) < 30)
         {
            if(OrderType() == OP_BUY )
               OrderModify(a+1, 0, OrderOpenPrice(), OrderTakeProfit()+maxTakeProfit*getPoint(), 0);
            else
               OrderModify(a+1, 0, OrderOpenPrice(), OrderTakeProfit()-maxTakeProfit*getPoint(), 0);
         } 
      }
      
   }

   int op = -1;

   double aa1 = avg_wpr(0, 0, bbf);
   double aa2 = avg_wpr(0, 1, 1); //10 for less signal
   double aa3 = avg_wpr2(0, 0, tPeriod);
   double wpra =iCustom(Symbol(),0,"WPR", wpr_Period1, wpr_Period2, false, 1, 0);
  
   int t = GetLastOrder(mag, OP_SELL);

    rtrend = trend;
    if( t > 0 )
      {
         //if( OrderType() == OP_BUY && aa3 < -80) CloseOrder(t, OP_SELL);
         //if( OrderType() == OP_SELL && aa3 > -20) CloseOrder(t, OP_BUY);
      }
            
         if( wpra < -20 && aa1 < 0-aa1V && aa2 >= -20 && rtrend == 2)
         {
            if( checksell()) 
               op = 1; 
            if( TimeCurrent() - dp2 > 60)
            {
               dp2 = TimeCurrent();
               Print("op=",op,"trend=",trend,"wpr=",wpra,"aa1=",aa1,"aa2=",aa2);
            }
         }

         if( wpra > -80  && aa1 > aa1V-100 && aa2 <= -80 && rtrend == 1)
         {
            if( TimeCurrent() - dp2 > 60)
            {
               dp2 = TimeCurrent();
               Print("op=",op,"rtrend=",rtrend,"wpr=",wpra,"aa1=",aa1,"aa2=",aa2);
            }
            if( checkbuy() ) 
               op = 0; 
         }
   double lots = Lots;
   if( op != -1 && GetTotalOrders(mag, OP_SELL) < maxOrders) 
   {
      t = GetLastOrder(mag, OP_SELL);
      string s[2];
      s[0] = EAName+"逢低买入";
      s[1] = EAName+"逢高卖出";
      //if( mag == MAGICMA + 1) s[op] = NormalizeDouble(adx,1);
      if( t != -1 ){
         if( checkProfitOrders(mag) == False) CloseOrder(t, op);
         else
         {
            if( TimeCurrent() - OrderOpenTime() > orderPeriod) 
            {
               //add position
               OpenOrder(op, lots, StopLoss, TakeProfit, mag, s[op],2);
            }
         }
      }
      else{
            OpenOrder(op, lots, StopLoss, TakeProfit, mag, s[op],2); //new position
      }
   }
  
   return(0);
  }
// the end.