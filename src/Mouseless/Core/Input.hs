module Mouseless.Core.Input
  ( Event (..)
  , charToKey
  , parseKeyChar
  , directionFromChar
  ) where

import Data.Char (toLower)
import Mouseless.Core.Charset (Key (..))
import Mouseless.Core.Commands (MoveDir (..))

data Event
  = ActivationPressed
  | KeyChar !Char
  | MoveKey !MoveDir
  | Confirm
  | Cancel
  | ToggleMoveMode
  | ClickLeft
  | ClickRight
  | Quit
  deriving (Eq, Show)

parseKeyChar :: Char -> Maybe Event
parseKeyChar c =
  case toLower c of
    'h' -> Just (MoveKey MoveLeft)
    'j' -> Just (MoveKey MoveDown)
    'k' -> Just (MoveKey MoveUp)
    'l' -> Just (MoveKey MoveRight)
    'm' -> Just ToggleMoveMode
    ' ' -> Just Confirm
    '\r' -> Just Confirm
    '\ESC' -> Just Cancel
    'q' -> Just Quit
    x | x `elem` labelChars -> Just (KeyChar (toLower x))
    _ -> Nothing
  where
    labelChars = "asdfghjklqwertyuiopzxcvbnm"

charToKey :: Char -> Maybe Key
charToKey c =
  case toLower c of
    'a' -> Just KeyA
    's' -> Just KeyS
    'd' -> Just KeyD
    'f' -> Just KeyF
    'g' -> Just KeyG
    'h' -> Just KeyH
    'j' -> Just KeyJ
    'k' -> Just KeyK
    'l' -> Just KeyL
    'q' -> Just KeyQ
    'w' -> Just KeyW
    'e' -> Just KeyE
    'r' -> Just KeyR
    't' -> Just KeyT
    'y' -> Just KeyY
    'u' -> Just KeyU
    'i' -> Just KeyI
    'o' -> Just KeyO
    'p' -> Just KeyP
    'z' -> Just KeyZ
    'x' -> Just KeyX
    'c' -> Just KeyC
    'v' -> Just KeyV
    'b' -> Just KeyB
    'n' -> Just KeyN
    'm' -> Just KeyM
    _ -> Nothing

directionFromChar :: Char -> Maybe MoveDir
directionFromChar c = do
  k <- charToKey c
  case k of
    KeyH -> Just MoveLeft
    KeyJ -> Just MoveDown
    KeyK -> Just MoveUp
    KeyL -> Just MoveRight
    _ -> Nothing
