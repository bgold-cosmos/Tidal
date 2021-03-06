{-# LANGUAGE ScopedTypeVariables #-}

module Sound.Tidal.EspGrid (tidalEspGridLink,cpsEsp,espgrid) where

{-
    EspGrid.hs - Provides ability to sync via the ESP Grid
    Copyright (C) 2020, David Ogborn and contributors

    This library is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This library is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this library.  If not, see <http://www.gnu.org/licenses/>.
-}

import Control.Concurrent.MVar
import Control.Concurrent (forkIO,threadDelay)
import Control.Monad (forever)
import Control.Exception
import Sound.OSC.FD
import Sound.Tidal.Tempo
import Sound.Tidal.Stream (Stream, sTempoMV)

parseEspTempo :: [Datum] -> Maybe (Tempo -> Tempo)
parseEspTempo d = do
  on :: Integer <- datum_integral (d!!0)
  bpm <- datum_floating (d!!1)
  t1 :: Integer <- datum_integral (d!!2)
  t2 <- datum_integral (d!!3)
  n :: Integer <- datum_integral (d!!4)
  let nanos = (t1*1000000000) + t2
  return $ \t -> t {
    atTime = ut_to_ntpr $ realToFrac nanos / 1000000000,
    atCycle = fromIntegral n,
    cps = bpm/60,
    paused = on == 0
    }

changeTempo :: MVar Tempo -> Packet -> IO ()
changeTempo t (Packet_Message msg) =
  case parseEspTempo (messageDatum msg) of
    Just f -> modifyMVarMasked_ t $ \t0 -> return (f t0)
    Nothing -> putStrLn "Warning: Unable to parse message from EspGrid as Tempo"
changeTempo _ _ = putStrLn "Serious error: Can only process Packet_Message"

tidalEspGridLink :: MVar Tempo -> IO ()
tidalEspGridLink _ = putStrLn "Function no longer supported, please use 'espgrid tidal' to connect to ESPgrid instead."

espgrid :: Stream -> IO ()
espgrid st = do
  let t = sTempoMV st
  socket <- openUDP "127.0.0.1" 5510
  _ <- forkIO $ forever $ do
    (do
      sendMessage socket $ Message "/esp/tempo/q" []
      response <- waitAddress socket "/esp/tempo/r"
      Sound.Tidal.EspGrid.changeTempo t response
      threadDelay 200000)
      `catch` (\e -> putStrLn $ "exception caught in tidalEspGridLink: " ++ show (e :: SomeException))
  return ()

cpsEsp :: Real t => t -> IO ()
cpsEsp t = do
  socket <- openUDP "127.0.0.1" 5510
  sendMessage socket $ Message "/esp/beat/tempo" [float (t*60)]
