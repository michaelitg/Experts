//+------------------------------------------------------------------+
//| MACD and Break Line                                              +
//+------------------------------------------------------------------+
#property copyright   "2016 michael"
#property link        "http://www.mql4.com"

#include<stdlib.mqh>
/*
半自动系统，用于Boller线上下轨自动挂单，复合仓交易。核心思想是从波段追趋势。
平仓后重新挂
*/

//----
extern int    orderdirection = 2;  //0 - buy 1 - sell 2 - all
extern int    UseMidAsUporDown = 2;  //1 - sell at mid 0 -- buy at mid
extern int    band = 40; //30
extern int    TakeProfit = 0;
extern int    StopLoss = 80;
extern double Lots = 1;  //2
extern double PriceChange = 10;
extern int    StepUpper = 4;
extern int    StepLower = 4;
extern string Filter1 = "-----Filter 1 width--------------";
extern double MinWidth = 80;

//------
int MagicBuy = 211010;
int MagicSell = 211040;
int glbOrderType[100];
int glbOrderTicket[100];

//must be global to use continually
datetime     pt = 0;
int debugStop = 0;

void init()
{
   if( Period() < 15) band *= 4;
   else if( Period() < 60) band *= 2;
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick(void)
  {
   if( debugStop == 1) return;
   Comment("myboller v0.13 1/8/2016 band=", band, " orderdirection=", orderdirection);
//---
// initial data checks
// it is important to make sure that the expert works with a normal
// chart and the user did not make any mistakes setting external
// variables (Lots, StopLoss, TakeProfit,
// TrailingStop)
   RefreshRates();
   //if(TimeCurrent() - Time[0] <  Period()*60 - 30) return;
   OpenTrade();
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//获取OP_BUY或OP_BUY_LIMIT或OP_BUY_STOP
int GetTotalOrders(int mag, int oType)
{
   int totalOrders = 0;
   for(int i=0;i<OrdersTotal();i++)
     {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==false) break;
      if( (mag != 0 && OrderMagicNumber()!= mag) || OrderSymbol()!=Symbol()) continue;
      //---- check order type
      if( OrderType() == oType || OrderType() == oType + 2 || OrderType() == oType + 4)
      {
         glbOrderType[totalOrders] = OrderType();
         glbOrderTicket[totalOrders] = OrderTicket();
         totalOrders++;
      }
     }
     return(totalOrders);
}

int CloseOrders(int mag)
{
   int totalOrders = 0;
   for(int i=0;i<OrdersTotal();i++)
     {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==false) break;
      if( (mag != 0 && OrderMagicNumber()!= mag && OrderMagicNumber()!= mag+1) || OrderSymbol()!=Symbol()) continue;
      //---- check order type
      {
         glbOrderTicket[totalOrders++] = OrderTicket();
      }
     }
     for(i=0;i<totalOrders;i++)
     {
      if(OrderSelect( glbOrderTicket[i], SELECT_BY_POS,MODE_TRADES)==false) break;
      if (OrderType() == OP_BUY) {
            if( OrderClose(OrderTicket(), OrderLots(), MarketInfo(OrderSymbol(), MODE_BID), 30, White)  == false)
            Print("Err (", GetLastError(), ") when close buy order ",OrderTicket());
            Sleep(500);
      }
      else{
         if (OrderType() == OP_SELL) {
               if( OrderClose(OrderTicket(), OrderLots(), MarketInfo(OrderSymbol(), MODE_ASK), 30, White) == false)
                Print("Err (", GetLastError(), ") when close sell order ",OrderTicket());
               Sleep(500);
         }
         else if( OrderDelete(OrderTicket()) == false) Print("Err (", GetLastError(), ") when delete order ",OrderTicket());
     }
    }
    return(totalOrders);
}

int OpenTrade()
  {
      double sl, tp,newtp;
      double lots = Lots;

       double bPrice = iBands(Symbol(),0,band,2,0,PRICE_CLOSE,MODE_LOWER,0);
       if( UseMidAsUporDown == 0) bPrice = iBands(Symbol(),0,band,2,0,PRICE_CLOSE,MODE_MAIN,0);
       double sPrice = iBands(Symbol(),0,band,2,0,PRICE_CLOSE,MODE_UPPER,0);
       if( UseMidAsUporDown == 1) sPrice = iBands(Symbol(),0,band,2,0,PRICE_CLOSE,MODE_MAIN,0);
       double buyPrice = NormalizeDouble(bPrice + StepUpper*getPoint(), Digits);
       double sellPrice = NormalizeDouble(sPrice - StepLower*getPoint(), Digits);

       //Filter1: 如果宽度太小，说明方向还没有选择好，删除所有挂单
       double w = sellPrice - buyPrice;
       if( w < MinWidth)
       {
         CloseOrders(MagicBuy+Period());
         CloseOrders(MagicSell+Period());
         return 0;
       }

      //挂单在下轨买入，止盈上轨，止损用参数
       sl = NormalizeDouble(buyPrice - StopLoss*getPoint(), Digits);
       tp = NormalizeDouble(sellPrice,Digits);
       //没有买单，下挂单
       int n = GetTotalOrders(MagicBuy+Period(), OP_BUY );

       if( n <= 0 && (orderdirection == 0 || orderdirection == 2 ))
       {
         OpenOrder(OP_BUYLIMIT, lots, buyPrice, sl, tp, MagicBuy+Period(), "mybollerv0.1", Blue);
       }
       else{
       //已经有买单且价格变化很大，修改价格到最新的上下轨
           int needModify = false;
           for( int k = 0; k < n; k++)
           {
              if( OrderSelect(glbOrderTicket[k], SELECT_BY_TICKET, MODE_TRADES) == false) break;
              if( OrderType() != OP_BUYLIMIT && OrderType() != OP_BUY) continue;
              if( TimeCurrent() - pt > 1800){
                  Print("===Deubg:ticket=",OrderTicket(),"tk=",OrderTakeProfit(),"tp=",tp,"gap=",MathAbs(OrderTakeProfit() - tp),"pricechange=",PriceChange*getPoint());
                  pt = TimeCurrent();
              }
              if((OrderType() == OP_BUYLIMIT && MathAbs(OrderOpenPrice() - buyPrice) >= PriceChange * getPoint()) || MathAbs(OrderTakeProfit() - tp) >= PriceChange * getPoint() )
              {
                  needModify = true;
                  Print("====DEBUG ",glbOrderTicket[k]," buyPrice= ", buyPrice," OrderOpenPrice=",OrderOpenPrice()," orderprofit=",OrderTakeProfit(), " gap=",PriceChange * getPoint(), " SL= ", sl, " TP= ", tp, "newtp=", newtp);

                  newtp = tp;
                  if( OrderType() == OP_BUY ) sl = OrderStopLoss();
                  if( OrderType() == OP_BUYLIMIT && MathAbs(OrderTakeProfit() - tp) >= 3*PriceChange * getPoint()) newtp = OrderTakeProfit() + PriceChange * getPoint();
                  if(OrderModify(glbOrderTicket[k], buyPrice, sl, newtp, 0, Green) == false)
                      Print("Err (", GetLastError(), ") Modify Buy Price= ", buyPrice, " SL= ", sl, " TP= ", tp, "newtp=", newtp);
                  /********************
                  
                  debugStop = 1;
                  
                  ************************/
              }
             
           }
           if( needModify){
               n = GetTotalOrders(MagicBuy+Period()+1, OP_BUY );
               for( k = 0; k < n; k++)
               {
                  if( OrderSelect(glbOrderTicket[k], SELECT_BY_TICKET, MODE_TRADES) == false) break;
                  if( OrderType() != OP_BUYLIMIT && OrderType() != OP_BUY) continue;
                  newtp = tp;
                  if( OrderType() == OP_BUY ) sl = OrderStopLoss();
                  if( OrderType() == OP_BUYLIMIT && MathAbs(OrderTakeProfit() - tp) >= 3*PriceChange * getPoint()) newtp = OrderTakeProfit() + PriceChange * getPoint();
                  if(OrderModify(glbOrderTicket[k], buyPrice, sl, NormalizeDouble(newtp+1*(newtp-buyPrice),Digits), 0, Green) == false)
                      Print("Err (", GetLastError(), ") Modify Buy Price= ", buyPrice, " SL= ", sl, " TP= ", tp, "newtp=", newtp);
              }
             
           }
      }

       //挂单在上轨卖出，止盈下轨，止损用参数
       sl = NormalizeDouble(sellPrice + StopLoss*getPoint(),Digits);
       tp = NormalizeDouble(buyPrice,Digits);
       //没有卖单，下挂单
       n = GetTotalOrders(MagicSell+Period(), OP_SELL );
       if( n <=  0 && (orderdirection == 1 || orderdirection == 2 ))
       {
         OpenOrder(OP_SELLLIMIT, lots, sellPrice, sl, tp, MagicSell+Period(), "mybollerv0.1", Red);
       }
       //已经有卖单且价格变化很大，修改价格到最新的上下轨
       else{
       needModify = false;
       for( k = 0; k < n; k++)
           {
           if( OrderSelect(glbOrderTicket[k], SELECT_BY_TICKET, MODE_TRADES) == false) break;
           if( OrderType() != OP_SELLLIMIT && OrderType() != OP_SELL) continue;
           if((OrderType() == OP_SELLLIMIT &&MathAbs(OrderOpenPrice() - sellPrice) >= PriceChange * getPoint()) || (MathAbs(OrderTakeProfit() - tp) >= PriceChange * getPoint() && MathAbs(OrderTakeProfit() - tp) < 3*PriceChange*getPoint()) )
           {
               needModify = true;
               newtp = tp;
               if( OrderType() == OP_SELL ) sl = OrderStopLoss();
               if( OrderType() == OP_SELLLIMIT && MathAbs(OrderTakeProfit() - tp) >= 3*PriceChange * getPoint()) newtp = OrderTakeProfit();
               if(OrderModify(glbOrderTicket[k], sellPrice, sl, newtp, 0, Red) == false)
                   Print("Err (", GetLastError(), ") Modify Sell Price= ", sellPrice, " SL= ", sl, " TP= ", tp, "newtp=", newtp);
              
           }
         }
         if( needModify){
            n = GetTotalOrders(MagicSell+Period()+1, OP_SELL );
            for( k = 0; k < n; k++)
              {
              if( OrderSelect(glbOrderTicket[k], SELECT_BY_TICKET, MODE_TRADES) == false) break;
              if( OrderType() != OP_SELLLIMIT && OrderType() != OP_SELL) continue;
                  newtp = tp;
                  if( OrderType() == OP_SELL ) sl = OrderStopLoss();
                  if( OrderType() == OP_SELLLIMIT && MathAbs(OrderTakeProfit() - tp) >= 3*PriceChange * getPoint()) newtp = OrderTakeProfit();
                  if(OrderModify(glbOrderTicket[k], sellPrice, sl, NormalizeDouble(newtp+1*(newtp-sellPrice),Digits), 0, Red) == false)
                      Print("Err (", GetLastError(), ") Modify Sell Price= ", sellPrice, " SL= ", sl, " TP= ", tp, "newtp=", newtp);
                 
              }
         }
     }
   return(0);
  }

///-----------------common-------------
double getPoint()
{
      double point=MarketInfo(Symbol(),MODE_POINT);
      if( point <= 0.0001) point = 0.0001;
      else point = 0.01;
      if( Ask > 800 && Ask < 1500) point = 0.1;  //gold
      if( Ask > 1500) point = 1;
      return(point);
}

void OpenOrder(int op, double aLots, double aprice, double aStopLoss, double aTakeProfit, int mag, string c="", int clr=Blue)
{
           double point = getPoint();
           if( c == "") c = "myea openorder";
           RefreshRates();
           double onelot = 1;
           if( aLots >= 4) onelot = 2;
           if( Ask < 500){
             onelot *= 0.1;  //AUD
             aLots *= 0.1;
           }
           double lot = 0;
           int    factor = 0;  //one long, one short
           int    n = 0;
           if( op == 0 || op == 2)
                     n = GetTotalOrders(mag+1, OP_BUY );
           else
                    n = GetTotalOrders(mag+1, OP_SELL );
                
           while( lot < aLots - n)
           {
                  if(OrderSend(Symbol(), op, onelot, NormalizeDouble(aprice, Digits), 500, NormalizeDouble(aStopLoss,Digits), NormalizeDouble(aTakeProfit+factor*(aTakeProfit-aprice),Digits), c, mag, 0, clr) == -1)
                  { 
                     string e = ErrorDescription(GetLastError());
                     Print("aStopLoss=",aStopLoss," myea Error = ",e); 
                  }
                  Sleep(1000);
                  lot += onelot;
                  factor = 1 - factor;
                  mag = mag + factor;   
           }
           Print("OpenOrder total:",(aLots - n),"n=",n,"onelot=",onelot,"==",aprice,"=lots=",aLots,"==op==",op,"=sl=",aStopLoss,"==tk",aTakeProfit);

}
