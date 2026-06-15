module Mouseful.Platform.Mock
  ( mockEnv
  , mockDemoEvents
  ) where

import Control.Concurrent.STM
  ( TVar
  , atomically
  , modifyTVar'
  , newTVarIO
  , readTVarIO
  )
import Mouseful.Core.Commands (Effect (..))
import Mouseful.Core.Geometry (Point (..), Screen (..))
import Mouseful.Core.Input (Event (..), defaultKeyBindings)
import Mouseful.Platform.Class (PlatformEnv (..))

data MockState = MockState
  { mockScreen :: !Screen
  , mockCursor :: !Point
  , mockEffects :: ![Effect]
  , mockEvents :: ![Event]
  }
  deriving (Eq, Show)

mockEnv :: IO (PlatformEnv, TVar MockState)
mockEnv = do
  ref <-
    newTVarIO
      MockState
        { mockScreen = Screen 1920 1080
        , mockCursor = Point 960 540
        , mockEffects = []
        , mockEvents = mockDemoEvents
        }
  let env =
        PlatformEnv
          { envGetScreen = mockGetScreen ref
          , envGetCursor = mockGetCursor ref
          , envNextEvent = mockNextEvent ref
          , envRunEffect = mockRunEffect ref
          , envBindings = defaultKeyBindings
          }
  pure (env, ref)

mockGetScreen :: TVar MockState -> IO Screen
mockGetScreen ref = mockScreen <$> readTVarIO ref

mockGetCursor :: TVar MockState -> IO Point
mockGetCursor ref = mockCursor <$> readTVarIO ref

mockNextEvent :: TVar MockState -> IO Event
mockNextEvent ref = do
  st <- readTVarIO ref
  case mockEvents st of
    [] -> pure Quit
    (ev : rest) -> do
      atomically (modifyTVar' ref (\s -> s {mockEvents = rest}))
      pure ev

mockRunEffect :: TVar MockState -> Effect -> IO ()
mockRunEffect ref eff =
  atomically $
    modifyTVar' ref (\s -> s {mockEffects = mockEffects s ++ [eff]})

-- | Activation, type "as" (first coarse cell), confirm fine grid selection "a".
mockDemoEvents :: [Event]
mockDemoEvents =
  [ ActivationPressed
  , KeyChar 'a'
  , KeyChar 's'
  , ActivationPressed
  , KeyChar 'a'
  , Cancel
  , Quit
  ]
