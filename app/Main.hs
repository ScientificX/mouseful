module Main where

import Control.Exception (bracket)
import Mouseful.App (runMouseful)
import Mouseful.Core.State (defaultConfig)
import Mouseful.Platform.MacOS (macosAvailable, macosEnv, macosShutdown)
import Mouseful.Platform.Mock (mockEnv)
import System.Environment (getArgs)

main :: IO ()
main = do
  args <- getArgs
  case args of
    ("--mock" : _) -> do
      (env, _) <- mockEnv
      runMouseful env defaultConfig
    _ ->
      if macosAvailable
        then
          bracket macosEnv (\_ -> macosShutdown) $ \env ->
            runMouseful env defaultConfig
        else fail "mouseful currently targets macOS"
