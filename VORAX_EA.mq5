//+------------------------------------------------------------------+
//|                                                       VORAX_EA.mq5 |
//|                                   VORAX™ Ultra-Fast Scalping EA   |
//|                           Copyright 2024 - Professional Edition   |
//|                                                                    |
//|  HUNT VOLATILITY. EXPLOIT MOMENTUM.                              |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024"
#property link      "https://github.com/wesamtaraf1984-ux"
#property version   "2.1"
#property strict
#property description "VORAX™ - Ultra-Fast Multi-Asset Scalping EA"

//==================================================================
// STANDARD MQL5 LIBRARIES
//==================================================================

#include <Trade\Trade.mqh>

//==================================================================
// VORAX MODULES
//==================================================================

#include <VORAX_Defines.mqh>
#include <VORAX_Utils.mqh>
#include <VORAX_SymbolConfig.mqh>
#include <VORAX_Volatility.mqh>
#include <VORAX_Pressure.mqh>
#include <VORAX_Momentum.mqh>
#include <VORAX_Risk.mqh>
#include <VORAX_Signal.mqh>
#include <VORAX_Execution.mqh>
#include <VORAX_PositionManager.mqh>
#include <VORAX_Reinforcement.mqh>
#include <VORAX_Dashboard.mqh>
#include <VORAX_News.mqh>
#include <VORAX_SessionManager.mqh>

//==================================================================
// INPUT PARAMETERS
//==================================================================

input group "=== GENERAL SETTINGS ==="
input bool TradeGold       = true;
input bool TradeBitcoin    = true;
input bool DebugMode       = false;
input bool ShowDashboard   = true;

input group "=== GOLD (XAUUSD) - RISK MANAGEMENT ==="
input double Gold_RiskPercentPerTrade = 0.50;
input double Gold_MaxDailyLoss        = 2.00;
input double Gold_MaxDrawdown         = 5.00;
input double Gold_MaxSpread           = 1.5;

input group "=== GOLD (XAUUSD) - ENTRY SIGNALS ==="
input double Gold_MinimumPressure          = 65.0;
input double Gold_MinimumPressureDiff      = 18.0;
input double Gold_MinimumMomentumStrength  = 50.0;

input group "=== GOLD (XAUUSD) - STOP LOSS & TP ==="
input double Gold_MinSLPoints              = 0.50;
input double Gold_MaxSLPoints              = 2.50;
input double Gold_SLVolatilityMultiplier   = 1.2;
input double Gold_TPRiskRewardRatio        = 1.50;

input group "=== GOLD (XAUUSD) - SESSION ==="
input string Gold_SessionStart = "09:00";
input string Gold_SessionEnd   = "17:00";
input bool Gold_TradeOnSession = true;

input group "=== BITCOIN (BTCUSD) - RISK MANAGEMENT ==="
input double Bitcoin_RiskPercentPerTrade = 0.50;
input double Bitcoin_MaxDailyLoss        = 2.00;
input double Bitcoin_MaxDrawdown         = 5.00;
input double Bitcoin_MaxSpread           = 75.0;

input group "=== BITCOIN (BTCUSD) - ENTRY SIGNALS ==="
input double Bitcoin_MinimumPressure         = 62.0;
input double Bitcoin_MinimumPressureDiff     = 16.0;
input double Bitcoin_MinimumMomentumStrength = 48.0;

input group "=== BITCOIN (BTCUSD) - STOP LOSS & TP ==="
input double Bitcoin_MinSLPoints            = 50.0;
input double Bitcoin_MaxSLPoints            = 300.0;
input double Bitcoin_SLVolatilityMultiplier = 1.3;
input double Bitcoin_TPRiskRewardRatio      = 1.50;

input group "=== BITCOIN (BTCUSD) - SESSION ==="
input string Bitcoin_SessionStart = "00:00";
input string Bitcoin_SessionEnd   = "23:59";
input bool Bitcoin_TradeOnSession = true;

input group "=== REINFORCEMENT (ADD-ON) ==="
input bool AllowReinforcement            = true;
input int MaxReinforcementTrades         = 1;
input double MinTimeBetweenReinforcement = 30.0;

input group "=== NEWS FILTER ==="
input bool NewsFilterEnabled = false;
input int NewsMinutesBefore  = 5;
input int NewsMinutesAfter   = 10;

input group "=== EXECUTION ==="
input int MaxTradesPerDay   = 20;
input int MaxTradesPerHour  = 5;
input int MaxOpenPositions  = 2;

//==================================================================
// GLOBAL OBJECTS / MANAGERS
//==================================================================

CLogger *logger = NULL;

CSymbolConfigManager *configManager = NULL;

CRiskManager *goldRiskManager = NULL;
CRiskManager *bitcoinRiskManager = NULL;

//--- Gold
CVolatilityAnalyzer *goldVolatility = NULL;
CPressureAnalyzer *goldPressure = NULL;
CMomentumAnalyzer *goldMomentum = NULL;
CSignalEngine *goldSignal = NULL;
CTradeExecutor *goldExecutor = NULL;
CPositionManager *goldPositionManager = NULL;
CReinforcementManager *goldReinforcement = NULL;
CSessionManager *goldSession = NULL;

//--- Bitcoin
CVolatilityAnalyzer *bitcoinVolatility = NULL;
CPressureAnalyzer *bitcoinPressure = NULL;
CMomentumAnalyzer *bitcoinMomentum = NULL;
CSignalEngine *bitcoinSignal = NULL;
CTradeExecutor *bitcoinExecutor = NULL;
CPositionManager *bitcoinPositionManager = NULL;
CReinforcementManager *bitcoinReinforcement = NULL;
CSessionManager *bitcoinSession = NULL;

//--- Dashboard
CDashboard *goldDashboard = NULL;
CDashboard *bitcoinDashboard = NULL;

//--- News
CNewsFilter *newsFilter = NULL;

//==================================================================
// STATE
//==================================================================

datetime lastGoldSignalTime   = 0;
datetime lastBitcoinSignalTime = 0;

string goldSymbol   = "XAUUSD";
string bitcoinSymbol = "BTCUSD";

ENUM_EA_STATUS eaStatus = EA_READY;

//--- Global trade counters
int      g_tradesToday = 0;
int      g_tradesThisHour = 0;

datetime g_tradeDayStart = 0;
datetime g_tradeHourStart = 0;

//==================================================================
// FUNCTION DECLARATIONS
//==================================================================

bool InitializeGold();
bool InitializeBitcoin();

void ReleaseGold();
void ReleaseBitcoin();

void ProcessGold();
void ProcessBitcoin();

void ExecuteGoldBuy(STradeSignal &signal);
void ExecuteGoldSell(STradeSignal &signal);

void ExecuteBitcoinBuy(STradeSignal &signal);
void ExecuteBitcoinSell(STradeSignal &signal);

void UpdateDashboards();

bool GlobalTradingAllowed();
void UpdateTradeCounters();
bool CanOpenNewTrade();

bool IsValidSignal(STradeSignal &signal);
bool IsValidStopLoss(STradeSignal &signal);

bool SymbolExists(string symbol);
string ResolveSymbol(string requested);

//==================================================================
// INITIALIZATION
//==================================================================

int OnInit()
{
   eaStatus = EA_READY;

   //--- Logger
   logger = new CLogger(DebugMode);

   if(logger == NULL)
      return INIT_FAILED;

   logger->Info("EA", "============================================================");
   logger->Info("EA", "VORAX Ultra-Fast Scalping EA v2.1 INITIALIZING");
   logger->Info("EA", "============================================================");

   //--- Configuration manager
   configManager = new CSymbolConfigManager(logger);

   if(configManager == NULL)
   {
      logger->Error("Init", "Failed to create configuration manager");
      return INIT_FAILED;
   }

   //--- News filter
   newsFilter = new CNewsFilter(
      NewsFilterEnabled,
      NewsMinutesBefore,
      NewsMinutesAfter,
      logger
   );

   if(newsFilter == NULL)
   {
      logger->Error("Init", "Failed to create news filter");
      return INIT_FAILED;
   }

   //--- Resolve actual broker symbols
   goldSymbol = ResolveSymbol("XAUUSD");
   bitcoinSymbol = ResolveSymbol("BTCUSD");

   if(TradeGold)
   {
      if(goldSymbol == "")
      {
         logger->Error("Init", "Unable to locate XAUUSD / Gold symbol");
         return INIT_FAILED;
      }

      logger->Info(
         "Init",
         "Detected Gold Symbol: " + goldSymbol
      );
   }

   if(TradeBitcoin)
   {
      if(bitcoinSymbol == "")
      {
         logger->Error("Init", "Unable to locate BTCUSD / Bitcoin symbol");
         return INIT_FAILED;
      }

      logger->Info(
         "Init",
         "Detected Bitcoin Symbol: " + bitcoinSymbol
      );
   }

   //--- Initialize counters
   g_tradeDayStart = iTime(_Symbol, PERIOD_D1, 0);
   g_tradeHourStart = TimeCurrent();

   g_tradesToday = 0;
   g_tradesThisHour = 0;

   //--- Gold
   if(TradeGold)
   {
      if(!InitializeGold())
      {
         logger->Error("Init", "Gold initialization failed");
         return INIT_FAILED;
      }
   }

   //--- Bitcoin
   if(TradeBitcoin)
   {
      if(!InitializeBitcoin())
      {
         logger->Error("Init", "Bitcoin initialization failed");
         return INIT_FAILED;
      }
   }

   eaStatus = EA_READY;

   logger->Info(
      "EA",
      "VORAX initialization complete - READY"
   );

   return INIT_SUCCEEDED;
}

//==================================================================
// GOLD INITIALIZATION
//==================================================================

bool InitializeGold()
{
   if(configManager == NULL)
      return false;

   SSymbolConfig *config = configManager->GetGoldConfig();

   if(config == NULL)
      return false;

   //--- Apply EA inputs
   config->symbol = goldSymbol;

   config->maxRiskPerTrade = Gold_RiskPercentPerTrade;
   config->maxDailyLoss = Gold_MaxDailyLoss;
   config->maxDrawdown = Gold_MaxDrawdown;
   config->maxSpread = Gold_MaxSpread;

   config->minimumPressure = Gold_MinimumPressure;
   config->minimumPressureDifference = Gold_MinimumPressureDiff;
   config->minimumMomentumStrength = Gold_MinimumMomentumStrength;

   config->minSLPoints = Gold_MinSLPoints;
   config->maxSLPoints = Gold_MaxSLPoints;
   config->slVolatilityMultiplier = Gold_SLVolatilityMultiplier;
   config->tpRiskRewardRatio = Gold_TPRiskRewardRatio;

   config->sessionStart = Gold_SessionStart;
   config->sessionEnd = Gold_SessionEnd;
   config->tradeOnSession = Gold_TradeOnSession;

   config->allowReinforcement = AllowReinforcement;
   config->maxReinforcementTrades = MaxReinforcementTrades;
   config->minTimeBetweenReinforcement = MinTimeBetweenReinforcement;

   //--- Global execution constraints
   config->maxPositions = MaxOpenPositions;
   config->maxTradesPerDay = MaxTradesPerDay;
   config->maxTradesPerHour = MaxTradesPerHour;

   if(!configManager->ValidateConfig(config))
   {
      logger->Error("Gold", "Invalid Gold configuration");
      return false;
   }

   //--- Risk
   goldRiskManager = new CRiskManager(
      goldSymbol,
      config,
      logger
   );

   if(goldRiskManager == NULL)
      return false;

   //--- Volatility
   goldVolatility = new CVolatilityAnalyzer(
      goldSymbol,
      config,
      logger
   );

   if(goldVolatility == NULL)
      return false;

   //--- Pressure
   goldPressure = new CPressureAnalyzer(
      goldSymbol,
      config,
      logger
   );

   if(goldPressure == NULL)
      return false;

   //--- Momentum
   goldMomentum = new CMomentumAnalyzer(
      goldSymbol,
      config,
      logger
   );

   if(goldMomentum == NULL)
      return false;

   //--- Signal
   goldSignal = new CSignalEngine(
      goldSymbol,
      config,
      goldPressure,
      goldMomentum,
      goldVolatility,
      logger
   );

   if(goldSignal == NULL)
      return false;

   //--- Execution
   goldExecutor = new CTradeExecutor(
      goldSymbol,
      config,
      goldRiskManager,
      logger
   );

   if(goldExecutor == NULL)
      return false;

   //--- Position manager
   goldPositionManager = new CPositionManager(
      goldSymbol,
      config,
      goldExecutor,
      goldVolatility,
      logger
   );

   if(goldPositionManager == NULL)
      return false;

   //--- Reinforcement
   goldReinforcement = new CReinforcementManager(
      goldSymbol,
      config,
      goldSignal,
      goldExecutor,
      goldPositionManager,
      goldRiskManager,
      logger
   );

   if(goldReinforcement == NULL)
      return false;

   //--- Session
   goldSession = new CSessionManager(
      config,
      logger
   );

   if(goldSession == NULL)
      return false;

   //--- Dashboard
   if(ShowDashboard)
   {
      goldDashboard = new CDashboard(
         goldSymbol,
         config,
         logger
      );

      if(goldDashboard == NULL)
         return false;
   }

   logger->Info(
      "Init",
      "Gold (" + goldSymbol + ") initialized successfully"
   );

   return true;
}

//==================================================================
// BITCOIN INITIALIZATION
//==================================================================

bool InitializeBitcoin()
{
   if(configManager == NULL)
      return false;

   SSymbolConfig *config = configManager->GetBitcoinConfig();

   if(config == NULL)
      return false;

   //--- Apply EA inputs
   config->symbol = bitcoinSymbol;

   config->maxRiskPerTrade = Bitcoin_RiskPercentPerTrade;
   config->maxDailyLoss = Bitcoin_MaxDailyLoss;
   config->maxDrawdown = Bitcoin_MaxDrawdown;
   config->maxSpread = Bitcoin_MaxSpread;

   config->minimumPressure = Bitcoin_MinimumPressure;
   config->minimumPressureDifference = Bitcoin_MinimumPressureDiff;
   config->minimumMomentumStrength = Bitcoin_MinimumMomentumStrength;

   config->minSLPoints = Bitcoin_MinSLPoints;
   config->maxSLPoints = Bitcoin_MaxSLPoints;
   config->slVolatilityMultiplier = Bitcoin_SLVolatilityMultiplier;
   config->tpRiskRewardRatio = Bitcoin_TPRiskRewardRatio;

   config->sessionStart = Bitcoin_SessionStart;
   config->sessionEnd = Bitcoin_SessionEnd;
   config->tradeOnSession = Bitcoin_TradeOnSession;

   config->allowReinforcement = AllowReinforcement;
   config->maxReinforcementTrades = MaxReinforcementTrades;
   config->minTimeBetweenReinforcement = MinTimeBetweenReinforcement;

   //--- Global execution constraints
   config->maxPositions = MaxOpenPositions;
   config->maxTradesPerDay = MaxTradesPerDay;
   config->maxTradesPerHour = MaxTradesPerHour;

   if(!configManager->ValidateConfig(config))
   {
      logger->Error("Bitcoin", "Invalid Bitcoin configuration");
      return false;
   }

   //--- Risk
   bitcoinRiskManager = new CRiskManager(
      bitcoinSymbol,
      config,
      logger
   );

   if(bitcoinRiskManager == NULL)
      return false;

   //--- Volatility
   bitcoinVolatility = new CVolatilityAnalyzer(
      bitcoinSymbol,
      config,
      logger
   );

   if(bitcoinVolatility == NULL)
      return false;

   //--- Pressure
   bitcoinPressure = new CPressureAnalyzer(
      bitcoinSymbol,
      config,
      logger
   );

   if(bitcoinPressure == NULL)
      return false;

   //--- Momentum
   bitcoinMomentum = new CMomentumAnalyzer(
      bitcoinSymbol,
      config,
      logger
   );

   if(bitcoinMomentum == NULL)
      return false;

   //--- Signal
   bitcoinSignal = new CSignalEngine(
      bitcoinSymbol,
      config,
      bitcoinPressure,
      bitcoinMomentum,
      bitcoinVolatility,
      logger
   );

   if(bitcoinSignal == NULL)
      return false;

   //--- Execution
   bitcoinExecutor = new CTradeExecutor(
      bitcoinSymbol,
      config,
      bitcoinRiskManager,
      logger
   );

   if(bitcoinExecutor == NULL)
      return false;

   //--- Position manager
   bitcoinPositionManager = new CPositionManager(
      bitcoinSymbol,
      config,
      bitcoinExecutor,
      bitcoinVolatility,
      logger
   );

   if(bitcoinPositionManager == NULL)
      return false;

   //--- Reinforcement
   bitcoinReinforcement = new CReinforcementManager(
      bitcoinSymbol,
      config,
      bitcoinSignal,
      bitcoinExecutor,
      bitcoinPositionManager,
      bitcoinRiskManager,
      logger
   );

   if(bitcoinReinforcement == NULL)
      return false;

   //--- Session
   bitcoinSession = new CSessionManager(
      config,
      logger
   );

   if(bitcoinSession == NULL)
      return false;

   //--- Dashboard
   if(ShowDashboard)
   {
      bitcoinDashboard = new CDashboard(
         bitcoinSymbol,
         config,
         logger
      );

      if(bitcoinDashboard == NULL)
         return false;
   }

   logger->Info(
      "Init",
      "Bitcoin (" + bitcoinSymbol + ") initialized successfully"
   );

   return true;
}

//==================================================================
// DEINITIALIZATION
//==================================================================

void OnDeinit(const int reason)
{
   if(logger != NULL)
   {
      logger->Info(
         "Deinit",
         "VORAX shutting down - Reason: " +
         IntegerToString(reason)
      );
   }

   //--- Dashboards
   if(goldDashboard != NULL)
   {
      goldDashboard->ClearDisplay();
      delete goldDashboard;
      goldDashboard = NULL;
   }

   if(bitcoinDashboard != NULL)
   {
      bitcoinDashboard->ClearDisplay();
      delete bitcoinDashboard;
      bitcoinDashboard = NULL;
   }

   ReleaseGold();
   ReleaseBitcoin();

   //--- Global managers
   if(newsFilter != NULL)
   {
      delete newsFilter;
      newsFilter = NULL;
   }

   if(configManager != NULL)
   {
      delete configManager;
      configManager = NULL;
   }

   if(logger != NULL)
   {
      logger->Info(
         "Deinit",
         "VORAX shutdown complete"
      );

      delete logger;
      logger = NULL;
   }

   eaStatus = EA_READY;
}

//==================================================================
// RELEASE GOLD
//==================================================================

void ReleaseGold()
{
   if(goldReinforcement != NULL)
   {
      delete goldReinforcement;
      goldReinforcement = NULL;
   }

   if(goldPositionManager != NULL)
   {
      delete goldPositionManager;
      goldPositionManager = NULL;
   }

   if(goldExecutor != NULL)
   {
      delete goldExecutor;
      goldExecutor = NULL;
   }

   if(goldSignal != NULL)
   {
      delete goldSignal;
      goldSignal = NULL;
   }

   if(goldMomentum != NULL)
   {
      delete goldMomentum;
      goldMomentum = NULL;
   }

   if(goldPressure != NULL)
   {
      delete goldPressure;
      goldPressure = NULL;
   }

   if(goldVolatility != NULL)
   {
      delete goldVolatility;
      goldVolatility = NULL;
   }

   if(goldRiskManager != NULL)
   {
      delete goldRiskManager;
      goldRiskManager = NULL;
   }

   if(goldSession != NULL)
   {
      delete goldSession;
      goldSession = NULL;
   }
}

//==================================================================
// RELEASE BITCOIN
//==================================================================

void ReleaseBitcoin()
{
   if(bitcoinReinforcement != NULL)
   {
      delete bitcoinReinforcement;
      bitcoinReinforcement = NULL;
   }

   if(bitcoinPositionManager != NULL)
   {
      delete bitcoinPositionManager;
      bitcoinPositionManager = NULL;
   }

   if(bitcoinExecutor != NULL)
   {
      delete bitcoinExecutor;
      bitcoinExecutor = NULL;
   }

   if(bitcoinSignal != NULL)
   {
      delete bitcoinSignal;
      bitcoinSignal = NULL;
   }

   if(bitcoinMomentum != NULL)
   {
      delete bitcoinMomentum;
      bitcoinMomentum = NULL;
   }

   if(bitcoinPressure != NULL)
   {
      delete bitcoinPressure;
      bitcoinPressure = NULL;
   }

   if(bitcoinVolatility != NULL)
   {
      delete bitcoinVolatility;
      bitcoinVolatility = NULL;
   }

   if(bitcoinRiskManager != NULL)
   {
      delete bitcoinRiskManager;
      bitcoinRiskManager = NULL;
   }

   if(bitcoinSession != NULL)
   {
      delete bitcoinSession;
      bitcoinSession = NULL;
   }
}

//==================================================================
// MAIN TICK
//==================================================================

void OnTick()
{
   UpdateTradeCounters();

   if(TradeGold)
      ProcessGold();

   if(TradeBitcoin)
      ProcessBitcoin();

   if(ShowDashboard)
      UpdateDashboards();
}

//==================================================================
// GLOBAL TRADING GATE
//==================================================================

bool GlobalTradingAllowed()
{
   if(MaxOpenPositions <= 0)
      return false;

   if(!CanOpenNewTrade())
   {
      eaStatus = EA_MAX_POSITIONS;
      return false;
   }

   if(newsFilter != NULL)
   {
      if(!newsFilter->IsTradeAllowed())
      {
         eaStatus = EA_NEWS_FILTER;
         return false;
      }
   }

   return true;
}

//==================================================================
// TRADE COUNTER UPDATE
//==================================================================

void UpdateTradeCounters()
{
   datetime now = TimeCurrent();

   datetime dayStart = iTime(_Symbol, PERIOD_D1, 0);

   if(dayStart != g_tradeDayStart)
   {
      g_tradeDayStart = dayStart;
      g_tradesToday = 0;
   }

   if(g_tradeHourStart == 0)
      g_tradeHourStart = now;

   if((now - g_tradeHourStart) >= 3600)
   {
      g_tradeHourStart = now;
      g_tradesThisHour = 0;
   }
}

//==================================================================
// NEW TRADE GATE
//==================================================================

bool CanOpenNewTrade()
{
   //--- Global trade limits
   if(MaxTradesPerDay > 0 &&
      g_tradesToday >= MaxTradesPerDay)
   {
      return false;
   }

   if(MaxTradesPerHour > 0 &&
      g_tradesThisHour >= MaxTradesPerHour)
   {
      return false;
   }

   //--- Current account positions
   int totalPositions = PositionsTotal();

   if(MaxOpenPositions > 0 &&
      totalPositions >= MaxOpenPositions)
   {
      return false;
   }

   return true;
}

//==================================================================
// GOLD PROCESSING
//==================================================================

void ProcessGold()
{
   if(goldVolatility == NULL ||
      goldPressure == NULL ||
      goldMomentum == NULL ||
      goldSignal == NULL ||
      goldPositionManager == NULL ||
      goldSession == NULL)
   {
      return;
   }

   //--- Always manage existing positions first
   goldPositionManager->UpdateAllPositions();

   //--- Update market analyzers
   if(!goldVolatility->Update())
      return;

   if(!goldPressure->Update())
      return;

   if(!goldMomentum->Update())
      return;

   //--- Session gate
   if(!goldSession->CanTrade())
   {
      eaStatus = EA_TRADING_DISABLED;
      return;
   }

   //--- News gate
   if(newsFilter != NULL &&
      !newsFilter->IsTradeAllowed())
   {
      eaStatus = EA_NEWS_FILTER;
      return;
   }

   //--- Extreme volatility protection
   if(goldVolatility->IsExtremeVolatility())
   {
      eaStatus = EA_EXTREME_VOLATILITY;
      return;
   }

   //--- Global limits
   if(!CanOpenNewTrade())
   {
      eaStatus = EA_MAX_POSITIONS;
      return;
   }

   //--- Signal
   STradeSignal signal = goldSignal->AnalyzeSignal();

   if(!IsValidSignal(signal))
   {
      eaStatus = EA_READY;
      return;
   }

   if(!goldSignal->IsSignalNew(signal))
   {
      eaStatus = EA_READY;
      return;
   }

   if(signal.signalType == SIGNAL_BUY)
   {
      ExecuteGoldBuy(signal);
      return;
   }

   if(signal.signalType == SIGNAL_SELL)
   {
      ExecuteGoldSell(signal);
      return;
   }

   eaStatus = EA_READY;
}

//==================================================================
// GOLD BUY
//==================================================================

void ExecuteGoldBuy(STradeSignal &signal)
{
   if(goldRiskManager == NULL ||
      goldExecutor == NULL ||
      goldPositionManager == NULL ||
      configManager == NULL)
   {
      return;
   }

   SSymbolConfig *config =
      configManager->GetGoldConfig();

   if(config == NULL)
      return;

   if(goldPositionManager->GetOpenPositionsCount() >=
      config->maxPositions)
   {
      eaStatus = EA_MAX_POSITIONS;
      return;
   }

   if(!IsValidStopLoss(signal))
      return;

   double point =
      SymbolInfoDouble(goldSymbol, SYMBOL_POINT);

   if(point <= 0.0)
      return;

   double slPoints =
      MathAbs(signal.entryPrice - signal.stopLoss) / point;

   if(slPoints <= 0.0)
      return;

   double lot =
      goldRiskManager->CalculateLotSize(slPoints);

   if(lot <= 0.0)
   {
      if(logger != NULL)
         logger->Warning(
            "Gold",
            "Invalid lot size calculated"
         );

      return;
   }

   ulong ticket =
      goldExecutor->ExecuteSignal(signal, lot);

   if(ticket > 0)
   {
      eaStatus = EA_BUY_SIGNAL;

      lastGoldSignalTime = TimeCurrent();

      g_tradesToday++;
      g_tradesThisHour++;

      // NOTE:
      // Do not record zero P/L as a completed trade.
      // The risk manager should record the result when the
      // position actually closes.
   }
}

//==================================================================
// GOLD SELL
//==================================================================

void ExecuteGoldSell(STradeSignal &signal)
{
   if(goldRiskManager == NULL ||
      goldExecutor == NULL ||
      goldPositionManager == NULL ||
      configManager == NULL)
   {
      return;
   }

   SSymbolConfig *config =
      configManager->GetGoldConfig();

   if(config == NULL)
      return;

   if(goldPositionManager->GetOpenPositionsCount() >=
      config->maxPositions)
   {
      eaStatus = EA_MAX_POSITIONS;
      return;
   }

   if(!IsValidStopLoss(signal))
      return;

   double point =
      SymbolInfoDouble(goldSymbol, SYMBOL_POINT);

   if(point <= 0.0)
      return;

   double slPoints =
      MathAbs(signal.stopLoss - signal.entryPrice) / point;

   if(slPoints <= 0.0)
      return;

   double lot =
      goldRiskManager->CalculateLotSize(slPoints);

   if(lot <= 0.0)
   {
      if(logger != NULL)
         logger->Warning(
            "Gold",
            "Invalid lot size calculated"
         );

      return;
   }

   ulong ticket =
      goldExecutor->ExecuteSignal(signal, lot);

   if(ticket > 0)
   {
      eaStatus = EA_SELL_SIGNAL;

      lastGoldSignalTime = TimeCurrent();

      g_tradesToday++;
      g_tradesThisHour++;
   }
}

//==================================================================
// BITCOIN PROCESSING
//==================================================================

void ProcessBitcoin()
{
   if(bitcoinVolatility == NULL ||
      bitcoinPressure == NULL ||
      bitcoinMomentum == NULL ||
      bitcoinSignal == NULL ||
      bitcoinPositionManager == NULL ||
      bitcoinSession == NULL)
   {
      return;
   }

   //--- Manage existing positions first
   bitcoinPositionManager->UpdateAllPositions();

   //--- Update analyzers
   if(!bitcoinVolatility->Update())
      return;

   if(!bitcoinPressure->Update())
      return;

   if(!bitcoinMomentum->Update())
      return;

   //--- Session
   if(!bitcoinSession->CanTrade())
   {
      eaStatus = EA_TRADING_DISABLED;
      return;
   }

   //--- News
   if(newsFilter != NULL &&
      !newsFilter->IsTradeAllowed())
   {
      eaStatus = EA_NEWS_FILTER;
      return;
   }

   //--- Extreme volatility
   if(bitcoinVolatility->IsExtremeVolatility())
   {
      eaStatus = EA_EXTREME_VOLATILITY;
      return;
   }

   //--- Global limits
   if(!CanOpenNewTrade())
   {
      eaStatus = EA_MAX_POSITIONS;
      return;
   }

   //--- Signal
   STradeSignal signal =
      bitcoinSignal->AnalyzeSignal();

   if(!IsValidSignal(signal))
   {
      eaStatus = EA_READY;
      return;
   }

   if(!bitcoinSignal->IsSignalNew(signal))
   {
      eaStatus = EA_READY;
      return;
   }

   if(signal.signalType == SIGNAL_BUY)
   {
      ExecuteBitcoinBuy(signal);
      return;
   }

   if(signal.signalType == SIGNAL_SELL)
   {
      ExecuteBitcoinSell(signal);
      return;
   }

   eaStatus = EA_READY;
}

//==================================================================
// BITCOIN BUY
//==================================================================

void ExecuteBitcoinBuy(STradeSignal &signal)
{
   if(bitcoinRiskManager == NULL ||
      bitcoinExecutor == NULL ||
      bitcoinPositionManager == NULL ||
      configManager == NULL)
   {
      return;
   }

   SSymbolConfig *config =
      configManager->GetBitcoinConfig();

   if(config == NULL)
      return;

   if(bitcoinPositionManager->GetOpenPositionsCount() >=
      config->maxPositions)
   {
      eaStatus = EA_MAX_POSITIONS;
      return;
   }

   if(!IsValidStopLoss(signal))
      return;

   double point =
      SymbolInfoDouble(bitcoinSymbol, SYMBOL_POINT);

   if(point <= 0.0)
      return;

   double slPoints =
      MathAbs(signal.entryPrice - signal.stopLoss) / point;

   if(slPoints <= 0.0)
      return;

   double lot =
      bitcoinRiskManager->CalculateLotSize(slPoints);

   if(lot <= 0.0)
   {
      if(logger != NULL)
         logger->Warning(
            "Bitcoin",
            "Invalid lot size calculated"
         );

      return;
   }

   ulong ticket =
      bitcoinExecutor->ExecuteSignal(signal, lot);

   if(ticket > 0)
   {
      eaStatus = EA_BUY_SIGNAL;

      lastBitcoinSignalTime = TimeCurrent();

      g_tradesToday++;
      g_tradesThisHour++;
   }
}

//==================================================================
// BITCOIN SELL
//==================================================================

void ExecuteBitcoinSell(STradeSignal &signal)
{
   if(bitcoinRiskManager == NULL ||
      bitcoinExecutor == NULL ||
      bitcoinPositionManager == NULL ||
      configManager == NULL)
   {
      return;
   }

   SSymbolConfig *config =
      configManager->GetBitcoinConfig();

   if(config == NULL)
      return;

   if(bitcoinPositionManager->GetOpenPositionsCount() >=
      config->maxPositions)
   {
      eaStatus = EA_MAX_POSITIONS;
      return;
   }

   if(!IsValidStopLoss(signal))
      return;

   double point =
      SymbolInfoDouble(bitcoinSymbol, SYMBOL_POINT);

   if(point <= 0.0)
      return;

   double slPoints =
      MathAbs(signal.stopLoss - signal.entryPrice) / point;

   if(slPoints <= 0.0)
      return;

   double lot =
      bitcoinRiskManager->CalculateLotSize(slPoints);

   if(lot <= 0.0)
   {
      if(logger != NULL)
         logger->Warning(
            "Bitcoin",
            "Invalid lot size calculated"
         );

      return;
   }

   ulong ticket =
      bitcoinExecutor->ExecuteSignal(signal, lot);

   if(ticket > 0)
   {
      eaStatus = EA_SELL_SIGNAL;

      lastBitcoinSignalTime = TimeCurrent();

      g_tradesToday++;
      g_tradesThisHour++;
   }
}

//==================================================================
// SIGNAL VALIDATION
//==================================================================

bool IsValidSignal(STradeSignal &signal)
{
   if(signal.signalType == SIGNAL_NONE)
      return false;

   if(signal.entryPrice <= 0.0)
      return false;

   if(signal.stopLoss <= 0.0)
      return false;

   return true;
}

//==================================================================
// STOP LOSS VALIDATION
//==================================================================

bool IsValidStopLoss(STradeSignal &signal)
{
   if(signal.signalType == SIGNAL_BUY)
   {
      if(signal.stopLoss >= signal.entryPrice)
         return false;
   }

   if(signal.signalType == SIGNAL_SELL)
   {
      if(signal.stopLoss <= signal.entryPrice)
         return false;
   }

   return true;
}

//==================================================================
// SYMBOL RESOLUTION
//==================================================================

bool SymbolExists(string symbol)
{
   if(symbol == "")
      return false;

   return SymbolSelect(symbol, true);
}

//==================================================================
// BROKER SYMBOL RESOLUTION
//==================================================================

string ResolveSymbol(string requested)
{
   //--- Exact symbol
   if(SymbolExists(requested))
      return requested;

   //--- Search all available symbols
   int total = SymbolsTotal(false);

   for(int i = 0; i < total; i++)
   {
      string name = SymbolName(i, false);

      if(name == "")
         continue;

      string upperName = name;
      StringToUpper(upperName);

      string upperRequested = requested;
      StringToUpper(upperRequested);

      // Exact root/suffix match
      if(StringFind(upperName, upperRequested) >= 0)
      {
         if(SymbolSelect(name, true))
            return name;
      }
   }

   return "";
}

//==================================================================
// DASHBOARD UPDATE
//==================================================================

void UpdateDashboards()
{
   if(TradeGold &&
      goldDashboard != NULL &&
      goldRiskManager != NULL &&
      goldPressure != NULL &&
      goldMomentum != NULL &&
      goldVolatility != NULL)
   {
      SAccountStats goldStats =
         goldRiskManager->GetAccountStats();

      goldDashboard->UpdateDisplay(
         goldPressure->GetData(),
         goldMomentum->GetData(),
         goldVolatility->GetData(),
         goldStats,
         eaStatus
      );
   }

   if(TradeBitcoin &&
      bitcoinDashboard != NULL &&
      bitcoinRiskManager != NULL &&
      bitcoinPressure != NULL &&
      bitcoinMomentum != NULL &&
      bitcoinVolatility != NULL)
   {
      SAccountStats bitcoinStats =
         bitcoinRiskManager->GetAccountStats();

      bitcoinDashboard->UpdateDisplay(
         bitcoinPressure->GetData(),
         bitcoinMomentum->GetData(),
         bitcoinVolatility->GetData(),
         bitcoinStats,
         eaStatus
      );
   }
}

//+------------------------------------------------------------------+
//| End of VORAX_EA.mq5                                               |
//+------------------------------------------------------------------+