module Mouseless.Core.Charset
  ( Key (..)
  , defaultKeys
  , keySequences
  , keysToText
  ) where

import Data.Char (toLower)
import Data.Text (Text)
import qualified Data.Text as T

data Key
  = KeyA | KeyS | KeyD | KeyF | KeyG
  | KeyH | KeyJ | KeyK | KeyL
  | KeyQ | KeyW | KeyE | KeyR | KeyT | KeyY | KeyU | KeyI | KeyO | KeyP
  | KeyZ | KeyX | KeyC | KeyV | KeyB | KeyN | KeyM
  deriving (Eq, Ord, Show, Enum, Bounded)

defaultKeys :: [Key]
defaultKeys =
  [ KeyA, KeyS, KeyD, KeyF, KeyG, KeyH, KeyJ, KeyK, KeyL
  , KeyQ, KeyW, KeyE, KeyR, KeyT, KeyY, KeyU, KeyI, KeyO, KeyP
  , KeyZ, KeyX, KeyC, KeyV, KeyB, KeyN, KeyM
  ]

-- | Generate unique key sequences for labeling grid cells (shortest first).
keySequences :: Int -> [[Key]]
keySequences n = take n (concat (map (\len -> sequences len defaultKeys) [1 ..]))
  where
    sequences 0 _ = [[]]
    sequences len ks =
      [ k : rest
      | k <- ks
      , rest <- sequences (len - 1) ks
      , k `notElem`   rest
      ]

keysToText :: [Key] -> Text
keysToText = T.pack . map keyChar
  where
    keyChar k = toLower (last (show k))
