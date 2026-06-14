{-# LANGUAGE LambdaCase #-}

module Mouseless.Platform.MacOS
  ( macosEnv
  , macosAvailable
  , macosShutdown
  ) where

import Data.Text (unpack)
import Mouseless.Core.Commands (Effect (..), MouseButton (..))
import Mouseless.Core.Geometry (Point (..), Rect (..), Screen (..))
import Mouseless.Core.Grid (LabeledCell (..))
import Mouseless.Core.Input (Event (..), parseKeyChar)
import Mouseless.Platform.Class (PlatformEnv (..))
import qualified Mouseless.Platform.MacOS.FFI as Native
import Mouseless.Platform.MacOS.FFI
  ( MLEventType (..)
  , MLGridCell (..)
  , mouselessBeep
  , mouselessClick
  , mouselessCursorX
  , mouselessCursorY
  , mouselessHideOverlay
  , mouselessInit
  , mouselessScreenHeight
  , mouselessScreenWidth
  , mouselessShowOverlay
  , mouselessWaitEvent
  , mouselessWarpCursor
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
  mouselessInit
  putStrLn "mouseless ready — press Cmd+7 to activate grid overlay (q to quit when focused)."
  pure
    PlatformEnv
      { envGetScreen = screenSize
      , envGetCursor = cursorPos
      , envNextEvent = waitInputEvent
      , envRunEffect = runEffect
      }

macosShutdown :: IO ()
macosShutdown = Native.mouselessShutdown

macosAvailable :: Bool
macosAvailable = os == "darwin"

screenSize :: IO Screen
screenSize = do
  w <- mouselessScreenWidth
  h <- mouselessScreenHeight
  pure (Screen w h)

cursorPos :: IO Point
cursorPos = do
  x <- mouselessCursorX
  y <- mouselessCursorY
  pure (Point x y)

waitInputEvent :: IO Event
waitInputEvent = do
  ev <- mouselessWaitEvent
  case mlEventType ev of
    MLActivation -> pure ActivationPressed
    MLKey ->
      case parseKeyChar (mlEventKey ev) of
        Just mapped -> pure mapped
        Nothing -> waitInputEvent
    _ -> waitInputEvent

runEffect :: Effect -> IO ()
runEffect = \case
  ShowOverlay cells -> mouselessShowOverlay (map toGridCell cells)
  HideOverlay -> mouselessHideOverlay
  WarpCursor (Point x y) -> mouselessWarpCursor x y
  NudgeCursor _ _ -> pure ()
  Click btn -> mouselessClick (buttonCode btn)
  Beep -> mouselessBeep

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
