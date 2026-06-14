module Mouseful.Core.Grid
  ( GridLevel (..)
  , LabeledCell (..)
  , GridConfig (..)
  , defaultGridConfig
  , subdivide
  , refineRegion
  ) where

import Data.Text (Text)
import Mouseful.Core.Charset (Key, keySequences, keysToText)
import Mouseful.Core.Geometry (Point (..), Rect (..), center)

data GridLevel = Coarse | Fine
  deriving (Eq, Show)

data GridConfig = GridConfig
  { coarseCols :: !Int
  , coarseRows :: !Int
  , fineCols :: !Int
  , fineRows :: !Int
  }
  deriving (Eq, Show)

defaultGridConfig :: GridConfig
defaultGridConfig =
  GridConfig
    { coarseCols = 8
    , coarseRows = 5
    , fineCols = 6
    , fineRows = 4
    }

data LabeledCell = LabeledCell
  { cellLabel :: ![Key]
  , cellLabelText :: !Text
  , cellRect :: !Rect
  , cellTarget :: !Point
  }
  deriving (Eq, Show)

subdivide :: GridConfig -> GridLevel -> Rect -> [LabeledCell]
subdivide cfg level region =
  let (cols, rows) = gridDims cfg level
      cellW = max 1 (rw region `div` cols)
      cellH = max 1 (rh region `div` rows)
      rects =
        [ Rect (rx region + c * cellW) (ry region + r * cellH) cellW cellH
        | r <- [0 .. rows - 1]
        , c <- [0 .. cols - 1]
        ]
      labels = keySequences (length rects)
   in zipWith mkCell labels rects
  where
    gridDims c Coarse = (coarseCols c, coarseRows c)
    gridDims c Fine = (fineCols c, fineRows c)
    mkCell lbl rect =
      LabeledCell
        { cellLabel = lbl
        , cellLabelText = keysToText lbl
        , cellRect = rect
        , cellTarget = center rect
        }

refineRegion :: LabeledCell -> Rect
refineRegion = cellRect
