{-# LANGUAGE LambdaCase #-}

module Mouseful.Platform.MacOS
  ( macosEnv
  , macosAvailable
  , macosShutdown
  ) where

import Data.Text (unpack)
import Mouseful.Core.Commands (Effect (..), MouseButton (..))
import Mouseful.Core.Geometry (Point (..), Rect (..), Screen (..))
import Mouseful.Core.Grid (LabeledCell (..))
import Mouseful.Core.Input (Event (..), KeyBindings, defaultKeyBindings, parseKeyChar)
import Mouseful.Platform.Class (PlatformEnv (..))
import qualified Mouseful.Platform.MacOS.FFI as Native
import Mouseful.Platform.MacOS.FFI
  ( MLEventType (..)
  , MLGridCell (..)
  , mousefulBeep
  , mousefulClick
  , mousefulCursorX
  , mousefulCursorY
  , mousefulHideOverlay
  , mousefulInit
  , mousefulScreenHeight
  , mousefulScreenWidth
  , mousefulShowOverlay
  , mousefulWaitEvent
  , mousefulWarpCursor
  , mlEventKey
  , mlEventType
  )
import System.Info (os)

-- | Initialize the native macOS layer (overlay, global hotkey, cursor control).
--
-- Activation key: F19 (rarely bound on most keyboards).
-- Requires Accessibility permission in System Settings.
macosEnv :: IO PlatformEnv
macosEnv = do
  mousefulInit
  putStrLn "mouseful ready — press Cmd+7 to activate grid overlay (q to quit when focused)."
  pure
    PlatformEnv
      { envGetScreen = screenSize
      , envGetCursor = cursorPos
      , envNextEvent = waitInputEvent defaultKeyBindings
      , envRunEffect = runEffect
      , envBindings = defaultKeyBindings
      }

macosShutdown :: IO ()
macosShutdown = Native.mousefulShutdown

macosAvailable :: Bool
macosAvailable = os == "darwin"

screenSize :: IO Screen
screenSize = do
  w <- mousefulScreenWidth
  h <- mousefulScreenHeight
  pure (Screen w h)

cursorPos :: IO Point
cursorPos = do
  x <- mousefulCursorX
  y <- mousefulCursorY
  pure (Point x y)

waitInputEvent :: KeyBindings -> IO Event
waitInputEvent kb = do
  ev <- mousefulWaitEvent
  case mlEventType ev of
    MLActivation -> pure ActivationPressed
    MLFreeRange -> pure ToggleMoveMode
    MLKey ->
      case parseKeyChar kb (mlEventKey ev) of
        Just mapped -> pure mapped
        Nothing -> waitInputEvent kb
    _ -> waitInputEvent kb

runEffect :: Effect -> IO ()
runEffect = \case
  ShowOverlay cells -> mousefulShowOverlay (map toGridCell cells)
  HideOverlay -> mousefulHideOverlay
  WarpCursor (Point x y) -> mousefulWarpCursor x y
  NudgeCursor _ _ -> pure ()
  Click btn -> mousefulClick (buttonCode btn)
  Beep -> mousefulBeep

buttonCode :: MouseButton -> Int
buttonCode = \case
  LeftButton -> 0
  RightButton -> 1
  MiddleButton -> 2

toGridCell :: LabeledCell -> MLGridCell
toGridCell cell =
  MLGridCell
    { mlCellX = rx (cellRect cell)
    , mlCellY = ry (cellRect cell)
    , mlCellW = rw (cellRect cell)
    , mlCellH = rh (cellRect cell)
    , mlCellLabel = unpack (cellLabelText cell)
    }
