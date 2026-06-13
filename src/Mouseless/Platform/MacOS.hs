{-# LANGUAGE LambdaCase #-}

module Mouseless.Platform.MacOS
  ( macosEnv
  , macosAvailable
  ) where

import Mouseless.Core.Commands (Effect (..), MoveDir (..))
import Mouseless.Core.Geometry (Point (..), Screen (..))
import Mouseless.Core.Grid (LabeledCell (..))
import Mouseless.Core.Input (Event (..), parseKeyChar)
import Mouseless.Platform.Class (PlatformEnv (..))
import System.Info (os)

-- | macOS platform layer (stdin demo stub).
--
-- Production implementation will use:
--   * CGEventTap for global hotkeys while idle
--   * NSPanel overlay (transparent, screen-saver level) for the grid
--   * CGWarpMouseCursorPosition / CGEventPost for cursor control
--
-- Requires Accessibility permission in System Settings.
macosEnv :: IO PlatformEnv
macosEnv =
  pure
    PlatformEnv
      { envGetScreen = pure (Screen 1920 1080)
      , envGetCursor = pure (Point 0 0)
      , envNextEvent = readStdinEvent
      , envRunEffect = renderEffect
      }

macosAvailable :: Bool
macosAvailable = os == "darwin"

readStdinEvent :: IO Event
readStdinEvent = do
  putStrLn "Key (a=activate grid, hjkl=move, space=click, esc=cancel, q=quit):"
  line <- getLine
  case lookupChar line >>= parseKeyChar of
    Just ev -> pure ev
    Nothing -> pure Quit
  where
    lookupChar [] = Nothing
    lookupChar (c : _) = Just c

renderEffect :: Effect -> IO ()
renderEffect = \case
  ShowOverlay cells -> do
    putStrLn "--- grid overlay ---"
    mapM_ printCell cells
  HideOverlay -> putStrLn "--- hide overlay ---"
  WarpCursor (Point x y) -> putStrLn $ "warp cursor -> " ++ show x ++ "," ++ show y
  NudgeCursor dir n -> putStrLn $ "nudge " ++ show dir ++ " " ++ show n
  Click btn -> putStrLn $ "click " ++ show btn
  Beep -> putStrLn "beep"

printCell :: LabeledCell -> IO ()
printCell c =
  putStrLn $
    show (cellLabelText c)
      ++ " @ "
      ++ show (cellTarget c)
