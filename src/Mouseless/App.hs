module Mouseless.App (runMouseless) where

import Control.Monad (unless)
import Control.Monad.IO.Class (MonadIO, liftIO)
import Mouseless.Core.Input (Event (..))
import Mouseless.Core.State
  ( AppState
  , Config
  , Mode (..)
  , initialState
  , step
  , stMode
  )
import Mouseless.Platform.Class (Platform (..), PlatformEnv, runPlatform)

runMouseless :: PlatformEnv -> Config -> IO ()
runMouseless env cfg = runPlatform env $ do
  screen <- getScreen
  cursor <- getCursor
  loop cfg (initialState screen cursor)

loop :: (Platform m, MonadIO m) => Config -> AppState -> m ()
loop cfg st = do
  ev <- nextEvent
  let (st', effects) = step cfg st ev
  mapM_ runEffect effects
  unless (ev == Quit && isIdle st') (loop cfg st')
  where
    isIdle s = case stMode s of
      Idle -> True
      _ -> False
