module Harness
  ( simulate
  , simulate_
  , runMousefulSim
  , SimulationState (..)
  , simEffects
  , simMode
  ) where

import Control.Monad.State.Strict
  ( State
  , gets
  , modify'
  , runState
  )
import Mouseful.Core.Commands (Effect)
import Mouseful.Core.Geometry (Point, Screen)
import Mouseful.Core.Input (Event)
import Mouseful.Core.State
  ( AppState
  , Config
  , Mode (..)
  , initialState
  , step
  , stMode
  )

data SimulationState = SimulationState
  { simAppState :: !AppState
  , simEffects :: ![Effect]
  }
  deriving (Eq, Show)

simMode :: SimulationState -> Mode
simMode = stMode . simAppState

simulate :: Config -> Event -> State SimulationState ()
simulate cfg ev = do
  st <- gets simAppState
  let (st', fx) = step cfg st ev
  modify' $ \s -> s { simAppState = st', simEffects = simEffects s ++ fx }

simulate_ :: Config -> [Event] -> State SimulationState ()
simulate_ cfg = mapM_ (simulate cfg)

runMousefulSim
  :: (Screen, Point)
  -> Config
  -> State SimulationState ()
  -> ([Effect], AppState)
runMousefulSim (screen, cursor) cfg m =
  let initSt = SimulationState
        { simAppState = initialState screen cursor
        , simEffects = []
        }
      ((), final) = runState m initSt
   in (reverse (simEffects final), simAppState final)