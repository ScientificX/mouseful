module Harness
  ( simulate
  , simulate_
  , runMouselessSim
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
import Mouseless.Core.Commands (Effect)
import Mouseless.Core.Geometry (Point, Screen)
import Mouseless.Core.Input (Event)
import Mouseless.Core.State
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

runMouselessSim
  :: (Screen, Point)
  -> Config
  -> State SimulationState ()
  -> ([Effect], AppState)
runMouselessSim (screen, cursor) cfg m =
  let initSt = SimulationState
        { simAppState = initialState screen cursor
        , simEffects = []
        }
      ((), final) = runState m initSt
   in (reverse (simEffects final), simAppState final)