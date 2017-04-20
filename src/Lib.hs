{-# LANGUAGE RecordWildCards #-}

module Lib
    ( someFunc
    ) where

import Data.Maybe
import Data.Time.Units
import Control.Concurrent.MVar
import Control.Concurrent
import Data.Time.Clock
import Data.Time.Calendar
import qualified System.Clock as Clock

import Debug.Trace as D

someFunc :: IO ()
someFunc = putStrLn "someFunc"

type Permit = Double

data RateLimiter
    = BurstyLimiter LimiterParams (MVar LimiterState)
    | SmoothWarmupLimiter LimiterParams SmoothWarmupParams (MVar LimiterState)
    -- = BurstyLimiter (Microsecond, Permit, MVar LimiterState)
    -- | SmoothWarmupLimiter (SmoothWarmupParams, MVar LimiterState)

data LimiterParams =
    LimiterParams
    { interval :: !Microsecond
    , maxPermits :: !Permit
    } deriving Show


data SmoothWarmupParams
    = SmoothWarmupParams
    { smoothWarmupPeriod :: !Microsecond
    , smoothSlope :: !Double
    , smoothThresholdPermits :: !Permit
    } deriving Show

data LimiterState
    = LimiterState
    { storedPermits :: !Permit
    , nextFreeTicket :: !Microsecond
    } deriving Show

smoothWarmupLimiter :: (TimeUnit a, TimeUnit b) => a -> b -> Double -> Double -> IO RateLimiter
smoothWarmupLimiter stableInterval warmupPeriod thresholdPermits coldFactor = do
    let coldInterval = fromMicroseconds $ truncate $ toDouble stableInterval * coldFactor :: Microsecond
    let maxP = thresholdPermits + 2 * toDouble warmupPeriod / (toDouble stableInterval + toDouble coldInterval)
    let slope = (toDouble coldInterval - toDouble stableInterval) / (maxP - thresholdPermits)
    state <- newMVar LimiterState
            { storedPermits = 0
            , nextFreeTicket = 0
            }
    let params = LimiterParams
            { interval = convertUnit stableInterval
            , maxPermits = maxP
            }
    let smoothParams = SmoothWarmupParams
            { smoothWarmupPeriod = convertUnit warmupPeriod
            , smoothSlope = slope
            , smoothThresholdPermits = thresholdPermits
            }
    print $ "limiter created with params: " ++ show params
    readMVar state >>= \s -> print $ "and state: " ++ show s
    pure $ SmoothWarmupLimiter params smoothParams state

burstyLimiter :: (TimeUnit a) => a -> Permit -> IO RateLimiter
burstyLimiter stableInterval maxP = do
    state <- newMVar LimiterState
            { storedPermits = 0
            , nextFreeTicket = 0
            }
    let params = LimiterParams
            { interval = convertUnit stableInterval
            , maxPermits = maxP
            }
    pure $ BurstyLimiter params state

simpleLimiter :: (TimeUnit a) => a -> IO RateLimiter
simpleLimiter interval = burstyLimiter interval 0


reserveBursty :: LimiterParams
              -> LimiterState
              -> Permit
              -> (LimiterState, Maybe Microsecond)
reserveBursty p s permitsToTake = error "wip reserve bursty"

reserveSmooth
  :: LimiterParams
  -> LimiterState
  -> SmoothWarmupParams
  -> Permit
  -> (LimiterState, Maybe Microsecond)
reserveSmooth p s permitsToTake smoothP = error "wip reserve smooth"



toDouble :: TimeUnit a => a -> Double
toDouble = fromIntegral . toMicroseconds

storedPermitsToWaitTime :: SmoothWarmupParams -> Permit -> Double -> Microsecond
storedPermitsToWaitTime p storedPermits permitsToTake =
    micros
  where
    micros = error "wip storedPermitsToWaitTime"

-- coolDownInterval :: SmoothWarmupParams -> Microsecond
-- coolDownInterval p = fromMicroseconds $ truncate $
--     toDouble (smoothWarmupPeriod p) / maxPermit
--   where
--     maxPermit = smoothMaxPermits p
--
-- acquire (BurstyLimiter (interval, maxPermits, mState)) requiredPermits = do
--     mbWaitTime <- modifyMVar mState $ \state -> do
--         now <- getCurrentTimeMicro
--         print $ "now: " ++ show now
--         pure $ reserveBursty interval now maxPermits state requiredPermits
--     print $ "mb wait time for bursty limiter: " ++ show mbWaitTime
--     case mbWaitTime of
--         Nothing -> pure ()
--         Just timeToWait -> threadDelay (fromIntegral $ toMicroseconds timeToWait)
-- acquire (SmoothWarmupLimiter (params, mState)) requiredPermits = do
--     mbWaitTime <- modifyMVar mState $ \state -> do
--         now <- getCurrentTimeMicro
--         print $ "reserve: " ++ show (reserveSmooth params now requiredPermits state)
--         pure $ reserveSmooth params now requiredPermits state
--     print $ "waiting stuff: " ++ show mbWaitTime
--     case mbWaitTime of
--         Nothing -> pure ()
--         Just timeToWait -> threadDelay (fromIntegral $ toMicroseconds timeToWait)
--
--
-- reserveSmooth
--   :: SmoothWarmupParams
--   -> Microsecond
--   -> Double
--   -> LimiterState
--   -> (LimiterState, Maybe Microsecond)
-- reserveSmooth p now requiredPermits state = (state', toWait)
--   where
--     nextFree = nextFreeTicket state
--     newPermits =
--       fromInteger (toMicroseconds (now - nextFree)) /
--       fromInteger (toMicroseconds $ coolDownInterval p)
--     storedPermitsToSpend = min requiredPermits (storedPermits state)
--     freshPermits = requiredPermits - storedPermitsToSpend
--     waitTime =
--       storedPermitsToWaitTime p state requiredPermits +
--       freshPermits * toDouble (smoothStableInterval p)
--     toWait =
--       if nextFree <= now
--         then Nothing
--         else Just (nextFree - now)
--     storedPermits' = storedPermits state - storedPermitsToSpend -- min (smoothMaxPermits p) (storedPermits state + newPermits)
--     nextFreeTicket' = max now nextFree + fromMicroseconds (truncate waitTime)
--     state' =
--       state
--       { storedPermits = storedPermits'
--       , nextFreeTicket = nextFreeTicket'
--       }
--
-- reserveSimple :: Microsecond -> Microsecond -> Double -> LimiterState -> (LimiterState, Maybe Microsecond)
-- reserveSimple interval now requiredPermits state = (state', toWait)
--   where
--     nextFree = nextFreeTicket state
--     waitTime = max 0 (nextFree - now)
--     -- TODO storedPermits isn't valid for the simple rate limiter
--     state' = state {nextFreeTicket = max now nextFree + interval}
--     toWait =
--         if waitTime > 0
--         then Just waitTime
--         else Nothing
--
-- reserveBursty :: Microsecond -> Microsecond -> Double -> LimiterState -> Double -> (LimiterState, Maybe Microsecond)
-- reserveBursty = error "wip reserve bursty"
-- -- reserveBursty interval now maxPermits state requiredPermits = (state', toWait)
-- --   where
-- --     nextFree = nextFreeTicket state
-- --     stored = storedPermits state
-- --     waitTime = max 0 (nextFree - now)
-- --     nextFree' =
-- --         if stored > 0
-- --         then nextFree
-- --         else max now nextFree + interval
-- --     state' = state {storedPermits = max 0 (stored - requiredPermits), nextFreeTicket = nextFree'}
-- --     toWait =
-- --         if stored == 0 && waitTime > 0
-- --         then Just waitTime
-- --         else Nothing
--
-- getCurrentTimeMicro :: IO Microsecond
-- getCurrentTimeMicro = do
--     t <- Clock.getTime Clock.Realtime
--     let s = truncate $ fromIntegral (Clock.sec t) * 1000000
--     let micro = truncate $ fromIntegral (Clock.nsec t) / 1000
--     pure $ fromMicroseconds (s + micro)
--
--
--
-- storedPermitsToWaitTime :: SmoothWarmupParams -> LimiterState -> Double -> Double
-- storedPermitsToWaitTime p state permitsToTake =
--     micros
--   where
--     slope = smoothSlope p
--     thresholdPermits = smoothThresholdPermits p
--     stableInterval = smoothStableInterval p
--     availablePermitsAboveThreshold = max 0 (storedPermits state - thresholdPermits)
--
--     permitsAboveThresholdToTake = max 0 (min availablePermitsAboveThreshold permitsToTake)
--     permitsBelowThresholdToTake = max 0 (permitsToTake - permitsAboveThresholdToTake)
--
--     length = permitsToTime availablePermitsAboveThreshold
--         + permitsToTime (availablePermitsAboveThreshold - permitsAboveThresholdToTake)
--     micros = permitsAboveThresholdToTake * length / 2
--         + (fromIntegral stableInterval * permitsBelowThresholdToTake)
--     permitsToTime :: Double -> Double
--     permitsToTime p = fromIntegral stableInterval + p * slope
--
--     -- availablePermitsBelowThreshold = min storedPermits thresholdPermits
--     -- permitsBelowThresholdToTake = min permitsToTake availablePermitsBelowThreshold
--     -- permitsAboveThresholdToTake = max 0 (permitsToTake - permitsBelowThresholdToTake)
--
-- --             ^
-- --    interval |                               /
-- --             |                              /|
-- --             |                             / |
-- --             |                            /  |
-- --             |                           /   |
-- --             |                          /|   |
-- --             |                         / |   |
-- --             |                        /  |   |
-- --             |                       /   |   |
-- --             |                      /    |   |
-- --             |                     / (3) |   |
-- --    stable   +---------------------------+   |
-- --  interval   |                    |      |   |
-- --             |                    |      |   |
-- --             |      (1)           |  (2) |   |
-- --             |                    |      |   |
-- --             +--------------------+------+---+
-- --                        threshold ^      ^   ^ maxPermits
-- -- permitsAboveThresholdToTake + threshold |
--
--     -- leftTime = permitsBelowThresholdToTake * stableInterval -- (1)
--     -- rightTime =
--     --     permitsAboveThresholdToTake * stableInterval -- (2)
--     --     + permitsAboveThresholdToTake * permitsAboveThresholdToTake * slope / 2 -- (3)
--     -- time = leftTime + rightTime
--
--
--
-- testLimiter :: IO ()
-- testLimiter = do
--     testLimiter <- smoothWarmupLimiter (1 :: Second) (1 :: Second) 10 2
--     let SmoothWarmupLimiter (p, mState) = testLimiter
--     now <- getCurrentTimeMicro
--     state <- readMVar mState
--     print $ "initial limiter: " ++ show (p, state)
--     print $ "now:" ++ show now
--     let x0@(state', t) = reserveSmooth p now 100 state
--     print $ x0
--     let x1 = reserveSmooth p now 10 state'
--     print x1
--     pure ()
--
-- testSimple :: IO ()
-- testSimple = do
--     testLimiter@(BurstyLimiter (p, maxP, mState)) <- simpleLimiter (5 :: Second)
--     now <- getCurrentTimeMicro
--     state <- readMVar mState
--     print $ "initial state: " ++ show state
--
-- testBursty :: IO ()
-- testBursty = do
--     testLimiter@(BurstyLimiter (i, maxP, mState)) <- burstyLimiter (5 :: Second) 10
--     error "wip testBursty"
