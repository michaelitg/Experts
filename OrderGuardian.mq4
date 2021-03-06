//+------------------------------------------------------------------+
//|                                                OrderGuardian.mq4 |
//|                                                          Michael |
//|                                           michaelitg@outlook.com |
//+------------------------------------------------------------------+
#property copyright "Michael"
#property link      "michaelitg@outlook.com"

#define TP_PRICE_LINE "OG TP Price Line"
#define SL_PRICE_LINE "OG SL Price Line"
#define MSG           "OG Message"

//---- input parameters
extern string  Orders          = "*";           // Order number or * for all
extern string  comm0           = "Order type 0 - buy 1 - sell -1 - all";
extern int     OrderMainType   = -1;
extern string  comm1           = "Only show the lines, not do it except equity";
extern int     OrderTest       = 1;
extern string  comm2           = "Method:0-Equity 1-ma 2-trendline(OG_TP/OG_SL) 3-SAR";
extern int     TP_Method       = 0;             // 获利方式：1-Envelopes包络线和均线，2-趋势线
extern int     SL_Method       = 0;             // 获利方式：1-Envelopes包络线和均线，2-趋势线, 3-SAR
extern double  TP_Equity       = 500;
extern double  SL_Equity       = 200;
extern string  SPLIT1          = "===TP Params===";
extern color   TP_LineColor    = LimeGreen;     // 获利价格线颜色
extern int     TP_TimeFrame    = 0;             // 获利价计算的时间图周期
extern int     TP_MA_Period    = 100;            // 获利均线周期
extern int     TP_MA_Method    = MODE_SMA;      // 获利均线计算方法
extern int     TP_MA_Price     = PRICE_CLOSE;   // 获利均线计算价格
extern double  TP_Env_Dev      = 0.1;           // 获利Envelopes偏s移百分比
extern int     TP_Shift        = 0;             // 获利价计算的shift值
extern string  SPLIT2          = "===SL Params===";
extern color   SL_LineColor    = Red;           // 止损价格线颜色
extern int     SL_TimeFrame    = 0;             // 止损价计算的时间图周期
extern int     SL_MA_Period    = 100;            // 止损均线计算方法
extern int     SL_MA_Method    = MODE_SMA;      // 止损均线计算方法
extern int     SL_MA_Price     = PRICE_CLOSE;   // 止损均线计算价格
extern double  SL_Env_Dev      = 0;             // 止损Envelopes偏移百分比
extern double  SL_SARStep      = 0.02;          // SAR止损的步长
extern double  SL_SARMax       = 0.5;           // SAR止损最大值
extern int     SL_Shift        = 0;             // 止损价计算的shift值

string TPObjName, SLObjName;
int    OrdersID[], OrdersCount, OpType;
double OrderProfits;
double OrderTotalLots, OrderAvgPrice;

//+------------------------------------------------------------------+
//| expert initialization function                                   |
//+------------------------------------------------------------------+
int init()
{
  if ((SL_Method == 3) && (SL_Shift < 1))
    SL_Shift = 1;
  ObjectMakeLabel( MSG+"1", 15, 15 );
  ObjectMakeLabel( MSG+"2", 15, 30 );
  return(0);
}

//+------------------------------------------------------------------+
//| expert deinitialization function                                 |
//+------------------------------------------------------------------+
int deinit()
{
  ObjectDelete(TP_PRICE_LINE);
  ObjectDelete(SL_PRICE_LINE);
  ObjectDelete(MSG+"1");
  ObjectDelete(MSG+"2");
  Comment("");

  return(0);
}

//+------------------------------------------------------------------+
//| expert start function                                            |
//+------------------------------------------------------------------+
int start()
{
  int i;
  double TPPrice, SLPrice;
  bool   SetTPObj = false, SetSLObj = false;
  string MesgText1, MesgText2;

  GetOrdersID();     // 获取需要管理的订单ID
  //opType is mixed, then set optype to main type
  if( OpType == -1 && OrderTotalLots > 0) OpType = OrderMainType;
  if( OrderTotalLots == 0) OpType = OrderMainType;
  
  /********************locate the lines (ma trendline or sar)**************************/
    if (TP_Method == 2)
      SetTPObj = FindObject(TPObjName) < 0;
    if (SL_Method == 2)
      SetSLObj = FindObject(SLObjName) < 0;
    if (SetTPObj || SetSLObj)
      SearchObjName(OpType, SetTPObj, SetSLObj);         // 搜寻获利止损线的对象名

    CalcPrice(TPPrice, SLPrice);
    double p = Ask;
    if( OrderTotalLots > 0) p = OrderAvgPrice;
    double lots = OrderTotalLots;
    if( Point < 0.001) lots *= 10;
    if( lots == 0) lots = 1;
    MesgText1 = "OrderGuardian: "+p+" Expected Profit:"+DoubleToStr(MathAbs(TPPrice-p)/GetPoint()*lots,0);
    if( TPPrice > SLPrice) MesgText1 += " Win/Lose:"+DoubleToStr((TPPrice-p)/(p-SLPrice),1);
    else MesgText1 +=" Win/Lose Rate:"+DoubleToStr((p-TPPrice)/(SLPrice-p),1);
    MesgText2 = "S/L @ ";
    if (SLPrice < 0)
      MesgText2 = MesgText2 + " __ ";
    else
      MesgText2 = MesgText2 + DoubleToStr(SLPrice, Digits);
    MesgText2 = MesgText2 + "   T/P @ ";
    if (TPPrice < 0)
      MesgText2 = MesgText2 + " __ ";
    else
      MesgText2 = MesgText2 + DoubleToStr(TPPrice, Digits);

    ShowTPSLLines(TPPrice, SLPrice);
  
  /*****close order if touch the lines and type is same***************/
  if (OpType >= 0 && OpType == OrderMainType && OrderTest == 0)   
  {
    for (i = 0; i < OrdersCount; i++)
    {
      if ((SLPrice > 0) &&
          (((OpType == OP_BUY)  && (Bid <= SLPrice)) ||
           ((OpType == OP_SELL) && (Bid >= SLPrice))))
        CloseOrder(OrdersID[i]);
      if ((TPPrice > 0) &&
          (((OpType == OP_BUY)  && (Bid >= TPPrice)) ||
           ((OpType == OP_SELL) && (Bid <= TPPrice))))
        CloseOrder(OrdersID[i]);
    }
  }
  color        LabelColor=Black;
  string       Font="Verdana";
  int          FontSize=9;
  ObjectSetText( MSG+"1", MesgText1, FontSize,Font, LabelColor );
  ObjectSetText( MSG+"2", MesgText2, FontSize,Font, LabelColor );
  
  /********************close all orders for equity method****************************/
  if(TP_Method == 0)
  {
      if( AccountEquity() >= TP_Equity || AccountEquity() <= SL_Equity )
      {
          for (i = 0; i < OrdersCount; i++)
          {
            CloseOrder(OrdersID[i]);
            Sleep(1000);
          }
      }
  }
  return(0);
}
//+------------------------------------------------------------------+
// === 获取订单ID ===
void GetOrdersID()
{
  int i, n, t, o;
  bool all;
  
  OrderProfits = 0;
  n = OrdersTotal();
  ArrayResize(OrdersID, n);
  all = StringFind(Orders, "*") >= 0;
  int getType = -1;
  OrderTotalLots = 0;
  OrderAvgPrice = 0;
  OpType = 0;
  for (i = 0, OrdersCount = 0; i < n; i++)
  {
    if( OrderSelect(i, SELECT_BY_POS) == false) continue;
    if (Symbol() == OrderSymbol())
    {
      t = OrderTicket();
      if (all || (StringFind(Orders, DoubleToStr(t, 0)) >= 0))
      {
        OrderTotalLots += OrderLots();
        OrderProfits += OrderProfit();
        OrderAvgPrice += OrderOpenPrice();
        o = OrderType();
        if (o < 2)
        {
          if ((getType >= 0) && (o != getType))
          {
            OpType = -1;
          }
          {
            getType = o;
            OrdersID[OrdersCount] = t;
            OrdersCount++;
          }
        }
      }
    }
  }
  if( OrdersCount > 0) OrderAvgPrice /= OrdersCount;
  if( OpType != -1) OpType = getType;
  if (OrdersCount == 0)
  {
    if (ObjectFind(TP_PRICE_LINE) >= 0)
      ObjectDelete(TP_PRICE_LINE);
    if (ObjectFind(SL_PRICE_LINE) >= 0)
      ObjectDelete(SL_PRICE_LINE);
  }
}

// === 寻找获利止损线 ===
void SearchObjName(int Type, bool GetTPObj = true, bool GetSLObj = true)
{
  int    i, ObjType, iAbove, iBelow, iTP = -1, iSL = -1;
  double MinAbove, MaxBelow, y1, y2;
  string ObjName;
  
  if (GetTPObj)
  {
    iTP = ObjectFind("OG_TP");
    if (iTP >= 0)
      TPObjName = "OG_TP";
  }
  if (GetSLObj)
  {
    iSL = ObjectFind("OG_SL");
    if (iSL >= 0)
      SLObjName = "OG_SL";
  }
  if( iTP >= 0 || iSL >= 0) return;
  
  MinAbove = 999999;
  MaxBelow = 0;
  iAbove   = -1;
  iBelow   = -1;
  for (i = 0; i < ObjectsTotal(); i++)
  {
    ObjName = ObjectName(i);
    if( StringSubstr(ObjName,0,1) == "#" ) continue; //skip the system lines for orders
    ObjType = ObjectType(ObjName);
    switch (ObjType)
    {
      case OBJ_HLINE:
        y1 = ObjectGet(ObjName, OBJPROP_PRICE1);
        y2 = y1;
        ///Print("ObjName=",ObjName,"y1=",y1,"y2=",y2);
        break;
      case OBJ_TREND :
      case OBJ_TRENDBYANGLE :
        y1 = CalcLineValue(ObjName, 0, 1, ObjType);
        y2 = y1;
        ///Print("ObjName=",ObjName,"y1=",y1,"y2=",y2);
        break;
      case OBJ_CHANNEL :
        y1 = CalcLineValue(ObjName, 0, MODE_UPPER, ObjType);
        y2 = CalcLineValue(ObjName, 0, MODE_LOWER, ObjType);
        break;
      default :
        y1 = -1;
        y2 = -1;
    }
    if ((y1 > 0) && (y1 < Bid) && (y1 > MaxBelow))         // 两条线都在当前价下方
    {
      MaxBelow = y1;
      iBelow   = i;
    }
    else if ((y2 > Bid) && (y2 < MinAbove))    // 两条线都在当前价上方
    {
      MinAbove = y2;
      iAbove   = i;
    }
    else                // 两条线一上一下
    {
      if ((y1 > 0) && (y1 < MinAbove))
      {
        MinAbove = y1;
        iAbove   = i;
      }
      if (y2 > MaxBelow)
      {
        MaxBelow = y2;
        iBelow   = i;
      }
    }
  }

  switch (Type)
  {
    case OP_BUY :
      iTP = iAbove;
      iSL = iBelow;
      break;
    case OP_SELL :
      iTP = iBelow;
      iSL = iAbove;
      break;
    default :
      iTP = -1;
      iSL = -1;
  }
  if (GetTPObj)
  {
    if (iTP >= 0)
      TPObjName = ObjectName(iTP);
  }
  if (GetSLObj)
  {
    if (iSL >= 0)
      SLObjName = ObjectName(iSL);
  }
  ///Print("iTP=",iTP,"iSL=",iSL,"TPObjName=",TPObjName,"iAbove=",iAbove,"iBelow=",iBelow);
}

double GetPoint()
{
   double ret = Point;
   if(Ask > 1500) ret = 1;
   if( StringFind(Symbol(), "pro") >= 0) ret *= 10;
   return ret;
}

// === 计算获利价和止损价 ===
void CalcPrice(double &TPPrice, double &SLPrice)
{
  if( OrderTotalLots < 1) OrderTotalLots *= 10;
  double po = GetPoint();
  // 止损价
  switch (SL_Method)
  {
    case 0:
      if( OrderTotalLots > 0) SLPrice = (AccountEquity()-SL_Equity) / OrderTotalLots;
      else SLPrice = AccountEquity()-SL_Equity;
      if( OrderTotalLots == 0)
      {
         if( Ask > SLPrice)
         {
            SLPrice = Ask + SLPrice*po;
         }
         else
         {
            SLPrice = Bid - SLPrice*po;
         }
      }
      else{
         if( OpType == OP_BUY)
         {
            SLPrice = Ask - SLPrice*po;
         }
         else
         {
            SLPrice = Bid + SLPrice*po;
         }
      }
      break;
    case 1 :
      SLPrice = (1 + SL_Env_Dev * 0.01) * iMA(NULL, SL_TimeFrame, SL_MA_Period, 0, SL_MA_Method, TP_MA_Price, SL_Shift);
      break;
    case 2 :
      SLPrice = CalcLineValue(SLObjName, SL_Shift); //, 2 - OpType);
      break;
    case 3 :
      SLPrice = iSAR(NULL, SL_TimeFrame, SL_SARStep, SL_SARMax, SL_Shift);
      break;
    default :
      SLPrice = -1;
  }
    // 获利价
  switch (TP_Method)
  {
    case 0:
      if( OrderTotalLots > 0) TPPrice = (TP_Equity - AccountEquity()) / OrderTotalLots;
      else TPPrice = TP_Equity - AccountEquity();
      if( OrderTotalLots == 0)
      {
         if( Ask > SLPrice)
         {
            TPPrice = Bid + TPPrice*po;
         }
         else
         {
            TPPrice = Ask - TPPrice*po;
         }
      }
      else{
         if( OpType == OP_BUY)
         {
            TPPrice = Bid + TPPrice*po;
         }
         else
         {
            TPPrice = Ask - TPPrice*po;
         }
      }
      break;
    case 1 :
      TPPrice = (1 + TP_Env_Dev * 0.01) * iMA(NULL, TP_TimeFrame, TP_MA_Period, 0, TP_MA_Method, TP_MA_Price, TP_Shift);
      break;
    case 2 :
      TPPrice = CalcLineValue(TPObjName, TP_Shift, 1 + OpType);
      break;
    default :
      TPPrice = -1;
  }
}

// === 计算直线在某个k线的值 ===
double CalcLineValue(string ObjName, int Shift, int ValueIndex = 1, int ObjType = -1)
{
  double y1, y2, delta, ret;
  int    i;
  
  if ((ObjType < 0) && (StringLen(ObjName) > 0))
    ObjType = ObjectType(ObjName);
  switch (ObjType)
  {
    case OBJ_HLINE:
        ret = ObjectGet(ObjName, OBJPROP_PRICE1);
        break;
    case OBJ_TREND :
    case OBJ_TRENDBYANGLE :
      ret = LineGetValueByShift(ObjName, Shift);
      break;
    case OBJ_CHANNEL :
      i     = GetBarShift(Symbol(), 0, ObjectGet(ObjName, OBJPROP_TIME3));
      delta = ObjectGet(ObjName, OBJPROP_PRICE3) - LineGetValueByShift(ObjName, i);
      y1 = LineGetValueByShift(ObjName, Shift);
      y2 = y1 + delta;
      if (ValueIndex == MODE_UPPER)
        ret = MathMax(y1, y2);
      else if (ValueIndex == MODE_LOWER)
        ret = MathMin(y1, y2);
      else
        ret = -1;      
      break;
    default :
      ret = -1;
  }
  return(ret);
}

// === 显示获利止损价水平线 ===
void ShowTPSLLines(double TPPrice, double SLPrice)
{
  if (TPPrice < 0)
    ObjectDelete(TP_PRICE_LINE);
  else
  {
    if (FindObject(TP_PRICE_LINE) < 0)
    {
      ObjectCreate(TP_PRICE_LINE, OBJ_HLINE, 0, 0, 0);
      ObjectSet(TP_PRICE_LINE, OBJPROP_COLOR, TP_LineColor);
      ObjectSet(TP_PRICE_LINE, OBJPROP_STYLE, STYLE_DASHDOTDOT);
      ObjectSet(TP_PRICE_LINE, OBJPROP_WIDTH, 1);    
    }
    ObjectMove(TP_PRICE_LINE, 0, Time[0], TPPrice);
  }

  if (SLPrice < 0)
    ObjectDelete(SL_PRICE_LINE);
  else
  {
    if (FindObject(SL_PRICE_LINE) < 0)
    {
      ObjectCreate(SL_PRICE_LINE, OBJ_HLINE, 0, 0, 0);
      ObjectSet(SL_PRICE_LINE, OBJPROP_COLOR, SL_LineColor);
      ObjectSet(SL_PRICE_LINE, OBJPROP_STYLE, STYLE_DASHDOTDOT);
      ObjectSet(SL_PRICE_LINE, OBJPROP_WIDTH, 1);    
    }
    ObjectMove(SL_PRICE_LINE, 0, Time[0], SLPrice);
  }
}

// === 查找对象 ===
int FindObject(string Name)
{
  if (StringLen(Name) <= 0)
    return(-1);
  else
    return(ObjectFind(Name));
}

// === 平仓 ===
void CloseOrder(int Ticket)
{
  double ClosePrice;
  string str[2] = {"TP", "SL"};
  int type;
  if (OrderSelect(Ticket, SELECT_BY_TICKET, MODE_TRADES))
  {
    type = OrderType();
    if( type != OrderMainType && OrderProfit() > 0) return;
    if (OrderType() == OP_BUY)
      ClosePrice = MarketInfo(Symbol(), MODE_BID);
    else
      ClosePrice = MarketInfo(Symbol(), MODE_ASK);
    if (OrderClose(Ticket, OrderLots(), ClosePrice, 0, Red))
      Print("Order #", Ticket, " was closed successfully at ", str[type], " ", ClosePrice);
    else
      Print("Order #", Ticket, " reached ", str[type], " ", ClosePrice, ", but failed to close for error ", GetLastError());
  }
}

// === 计算直线上的值 ===
double LineGetValueByShift(string ObjName, int Shift)
{
  double i1, i2, i, y1, y2, y;
  
  i1 = GetBarShift(Symbol(), 0, ObjectGet(ObjName, OBJPROP_TIME1));
  i2 = GetBarShift(Symbol(), 0, ObjectGet(ObjName, OBJPROP_TIME2));
  y1 = ObjectGet(ObjName, OBJPROP_PRICE1);
  y2 = ObjectGet(ObjName, OBJPROP_PRICE2);
  if (i1 < i2)
  {
    i  = i1;
    i1 = i2;
    i2 = i;
    y  = y1;
    y1 = y2;
    y2 = y;
  }
  //Print("Shift=",Shift,"i1=",i1,"i2=",i2,"y1=",y1,"y2=",y2);
  if (Shift > i1)
    y = (y2 - y1) / (i2 - i1) * (Shift - i1) + y1;
  else
    y = ObjectGetValueByShift(ObjName, Shift);
    
  return(y);
}

// === 取时间值的shift数 ===
int GetBarShift(string symbol, int timeframe, datetime time)
{
  int now;
  
  now = iTime(symbol, timeframe, 0);
  if (time < now + timeframe * 60)
    return(iBarShift(symbol, timeframe, time));
  else
  {
    if (timeframe == 0)
      timeframe = Period();
    return((now - time) / timeframe / 60);
  }
}

void ObjectMakeLabel( string n, int xoff, int yoff, int window = 0, int Corner=0 ) 
  {
   {
      ObjectCreate( ChartID(), n, OBJ_LABEL, window, 0, 0 );
      ObjectSet( n, OBJPROP_CORNER, Corner );
      ObjectSet( n, OBJPROP_XDISTANCE, xoff );
      ObjectSet( n, OBJPROP_YDISTANCE, yoff );
      ObjectSet( n, OBJPROP_BACK, false );
    }
  }
 
 