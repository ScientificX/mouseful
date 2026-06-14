module Main where

import Control.Exception (bracket)
import Mouseless.App (runMouseless)
import Mouseless.Core.State (defaultConfig)
import Mouseless.Platform.MacOS (macosAvailable, macosEnv, macosShutdown)
import Mouseless.Platform.Mock (mockEnv)
import System.Environment (getArgs)

main :: IO ()
main = do
  args <- getArgs
  case args of
    ("--mock" : _) -> do
      (env, _) <- mockEnv
      runMouseless env defaultConfig
    _ ->
      if macosAvailable
        then
          bracket macosEnv (\_ -> macosShutdown) $ \env ->
            runMouseless env defaultConfig
        else fail "mouseless currently targets macOS"
