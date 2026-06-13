module Mouseless.Core.Geometry
  ( Point (..)
  , Rect (..)
  , Screen (..)
  , center
  , contains
  , clampPoint
  , inset
  , rectFromPoints
  ) where

data Point = Point
  { px :: !Int
  , py :: !Int
  }
  deriving (Eq, Show)

data Rect = Rect
  { rx :: !Int
  , ry :: !Int
  , rw :: !Int
  , rh :: !Int
  }
  deriving (Eq, Show)

data Screen = Screen
  { sw :: !Int
  , sh :: !Int
  }
  deriving (Eq, Show)

center :: Rect -> Point
center (Rect x y w h) = Point (x + w `div` 2) (y + h `div` 2)

contains :: Rect -> Point -> Bool
contains (Rect x y w h) (Point px' py') =
  px' >= x && px' < x + w && py' >= y && py' < y + h

clampPoint :: Screen -> Point -> Point
clampPoint (Screen sw sh) (Point x y) =
  Point (clamp 0 (sw - 1) x) (clamp 0 (sh - 1) y)
  where
    clamp lo hi v = max lo (min hi v)

inset :: Int -> Rect -> Rect
inset margin (Rect x y w h) =
  Rect (x + margin) (y + margin) (max 1 (w - 2 * margin)) (max 1 (h - 2 * margin))

rectFromPoints :: Point -> Point -> Rect
rectFromPoints (Point x1 y1) (Point x2 y2) =
  let x = min x1 x2
      y = min y1 y2
      w = abs (x2 - x1)
      h = abs (y2 - y1)
   in Rect x y (max 1 w) (max 1 h)
