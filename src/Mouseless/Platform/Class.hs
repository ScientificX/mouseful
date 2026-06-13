{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE RankNTypes #-}

module Mouseless.Platform.Class
  ( Platform (..)
  , PlatformEnv (..)
  , PlatformM
  , runPlatform
  , withPlatform
  ) where

import Control.Monad.IO.Class (MonadIO, liftIO)
import Control.Monad.Reader (ReaderT, ask, runReaderT)
import Mouseless.Core.Commands (Effect (..))
import Mouseless.Core.Geometry (Point, Screen)
import Mouseless.Core.Grid (LabeledCell)
import Mouseless.Core.Input (Event)

class Monad m => Platform m where
  getScreen :: m Screen
  getCursor :: m Point
  nextEvent :: m Event
  runEffect :: Effect -> m ()

type PlatformM a = ReaderT PlatformEnv IO a

data PlatformEnv = PlatformEnv
  { envRunEffect :: Effect -> IO ()
  , envNextEvent :: IO Event
  , envGetScreen :: IO Screen
  , envGetCursor :: IO Point
  }

runPlatform :: PlatformEnv -> PlatformM a -> IO a
runPlatform env = flip runReaderT env

withPlatform :: PlatformEnv -> (forall m. (Platform m, MonadIO m) => m a) -> IO a
withPlatform env action = runPlatform env action

instance MonadIO m => Platform (ReaderT PlatformEnv m) where
  getScreen = ask >>= liftIO . envGetScreen
  getCursor = ask >>= liftIO . envGetCursor
  nextEvent = ask >>= liftIO . envNextEvent
  runEffect eff = ask >>= liftIO . (`envRunEffect` eff)
