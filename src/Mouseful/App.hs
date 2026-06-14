module Mouseful.App (runMouseful) where

import Control.Monad (unless)
import Control.Monad.IO.Class (MonadIO, liftIO)
import Mouseful.Core.Input (Event (..))
import Mouseful.Core.State
  ( AppState
  , Config
  , Mode (..)
  , initialState
  , step
  , stMode
  )
import Mouseful.Platform.Class (Platform (..), PlatformEnv, runPlatform)

runMouseful :: PlatformEnv -> Config -> IO ()
runMouseful env cfg = runPlatform env $ do
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
