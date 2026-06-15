module Mouseful.Core.Input
  ( Event (..)
  , KeyBindings (..)
  , defaultKeyBindings
  , labelChars
  , charToKey
  , parseKeyChar
  , directionFromChar
  ) where

import Data.Char (toLower)
import Mouseful.Core.Charset (Key (..))
import Mouseful.Core.Commands (MoveDir (..))

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

data KeyBindings = KeyBindings
  { kbMoveLeft   :: !Char
  , kbMoveDown   :: !Char
  , kbMoveUp     :: !Char
  , kbMoveRight  :: !Char
  , kbLeftClick  :: !Char
  , kbRightClick :: !Char
  , kbFreeRange  :: !Char
  , kbConfirm    :: !Char
  , kbCancel     :: !Char
  , kbQuit       :: !Char
  }
  deriving (Eq, Show)

defaultKeyBindings :: KeyBindings
defaultKeyBindings = KeyBindings
  { kbMoveLeft   = 'h'
  , kbMoveDown   = 'j'
  , kbMoveUp     = 'k'
  , kbMoveRight  = 'l'
  , kbLeftClick  = 'x'
  , kbRightClick = 'c'
  , kbFreeRange  = 'm'
  , kbConfirm    = ' '
  , kbCancel     = '\ESC'
  , kbQuit       = 'q'
  }

labelChars :: KeyBindings -> String
labelChars kb =
  filter (not . (`elem` actionChars) . toLower) allHomeRow
  where
    allHomeRow = "asdfghjklqwertyuiopzxcvbnm"
    actionChars = map toLower
      [ kbMoveLeft kb
      , kbMoveDown kb
      , kbMoveUp kb
      , kbMoveRight kb
      , kbLeftClick kb
      , kbRightClick kb
      , kbFreeRange kb
      , kbConfirm kb
      , kbCancel kb
      , kbQuit kb
      ]

parseKeyChar :: KeyBindings -> Char -> Maybe Event
parseKeyChar kb c =
  let lower = toLower c
  in case lower of
    _ | lower == toLower (kbMoveLeft kb)   -> Just (MoveKey MoveLeft)
    _ | lower == toLower (kbMoveDown kb)   -> Just (MoveKey MoveDown)
    _ | lower == toLower (kbMoveUp kb)     -> Just (MoveKey MoveUp)
    _ | lower == toLower (kbMoveRight kb)  -> Just (MoveKey MoveRight)
    _ | lower == toLower (kbFreeRange kb)  -> Just ToggleMoveMode
    _ | lower == toLower (kbLeftClick kb)  -> Just ClickLeft
    _ | lower == toLower (kbRightClick kb) -> Just ClickRight
    _ | lower == toLower (kbConfirm kb)    -> Just Confirm
    _ | lower == toLower (kbCancel kb)     -> Just Cancel
    _ | lower == toLower (kbQuit kb)       -> Just Quit
    _ | lower `elem` labelChars kb -> Just (KeyChar lower)
    _ -> Nothing

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
