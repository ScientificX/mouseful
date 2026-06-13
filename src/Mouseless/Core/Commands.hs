module Mouseless.Core.Commands
  ( MouseButton (..)
  , MoveDir (..)
  , Effect (..)
  ) where

import Mouseless.Core.Geometry (Point (..))
import Mouseless.Core.Grid (LabeledCell)

data MouseButton = LeftButton | RightButton | MiddleButton
  deriving (Eq, Show)

data MoveDir = MoveUp | MoveDown | MoveLeft | MoveRight
  deriving (Eq, Show)

data Effect
  = ShowOverlay ![LabeledCell]
  | HideOverlay
  | WarpCursor !Point
  | NudgeCursor !MoveDir !Int
  | Click !MouseButton
  | Beep
  deriving (Eq, Show)
