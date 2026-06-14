module Mouseful.Core.State
  ( MoveStyle (..)
  , Mode (..)
  , AppState (..)
  , Config (..)
  , defaultConfig
  , initialState
  , step
  ) where

import Data.List (isPrefixOf)
import Mouseful.Core.Charset (Key (..))
import Mouseful.Core.Commands
  ( Effect (..)
  , MouseButton (..)
  , MoveDir (..)
  )
import Mouseful.Core.Geometry
  ( Point (..)
  , Rect (..)
  , Screen (..)
  , clampPoint
  , contains
  )
import Mouseful.Core.Grid
  ( GridConfig
  , GridLevel (..)
  , LabeledCell (..)
  , defaultGridConfig
  , refineRegion
  , subdivide
  )
import Mouseful.Core.Input (Event (..), charToKey)

data MoveStyle = FreeRange | GridStep
  deriving (Eq, Show)

data Mode
  = Idle
  | GridOverlay
      { overlayLevel :: !GridLevel
      , overlayRegion :: !Rect
      , overlayCells :: ![LabeledCell]
      , typedKeys :: ![Key]
      }
  | CursorControl
      { moveStyle :: !MoveStyle
      , gridRegion :: !(Maybe Rect)
      }
  deriving (Eq, Show)

data AppState = AppState
  { stScreen :: !Screen
  , stCursor :: !Point
  , stMode :: !Mode
  }
  deriving (Eq, Show)

data Config = Config
  { cfgGrid :: !GridConfig
  , cfgFreeStep :: !Int
  , cfgGridStep :: !Int
  , cfgAutoFineGrid :: !Bool
  }
  deriving (Eq, Show)

defaultConfig :: Config
defaultConfig =
  Config
    { cfgGrid = defaultGridConfig
    , cfgFreeStep = 8
    , cfgGridStep = 24
    , cfgAutoFineGrid = True
    }

initialState :: Screen -> Point -> AppState
initialState screen cursor =
  AppState
    { stScreen = screen
    , stCursor = cursor
    , stMode = Idle
    }

step :: Config -> AppState -> Event -> (AppState, [Effect])
step cfg st ev =
  case (stMode st, ev) of
    (Idle, ActivationPressed) -> enterCoarseGrid cfg st
    (Idle, MoveKey dir) -> nudge cfg st dir
    (Idle, ToggleMoveMode) -> enterCursorControl st FreeRange
    (Idle, Quit) -> (st, [])
    (GridOverlay {}, Cancel) -> exitOverlay st
    (GridOverlay {}, ev') -> handleGrid cfg st ev'
    (CursorControl {}, Cancel) -> (st {stMode = Idle}, [HideOverlay])
    (CursorControl {}, ToggleMoveMode) -> toggleMoveStyle st
    (CursorControl {}, MoveKey dir) -> moveCursor cfg st dir
    (CursorControl {}, Confirm) -> (st, [Click LeftButton])
    (CursorControl {}, ClickLeft) -> (st, [Click LeftButton])
    (CursorControl {}, ClickRight) -> (st, [Click RightButton])
    (CursorControl {}, ActivationPressed) -> enterCoarseGrid cfg st
    (CursorControl {}, Quit) -> (st, [])
    _ -> (st, [Beep])

enterCoarseGrid :: Config -> AppState -> (AppState, [Effect])
enterCoarseGrid cfg st =
  let region = screenRect (stScreen st)
      cells = subdivide (cfgGrid cfg) Coarse region
      mode =
        GridOverlay
          { overlayLevel = Coarse
          , overlayRegion = region
          , overlayCells = cells
          , typedKeys = []
          }
   in (st {stMode = mode}, [ShowOverlay cells])

enterFineGrid :: Config -> AppState -> LabeledCell -> (AppState, [Effect])
enterFineGrid cfg st cell =
  let region = refineRegion cell
      cells = subdivide (cfgGrid cfg) Fine region
      mode =
        GridOverlay
          { overlayLevel = Fine
          , overlayRegion = region
          , overlayCells = cells
          , typedKeys = []
          }
   in (st {stMode = mode}, [ShowOverlay cells])

handleGrid :: Config -> AppState -> Event -> (AppState, [Effect])
handleGrid cfg st ev =
  case (stMode st, ev) of
    (overlay@GridOverlay {overlayCells = cells, typedKeys = typed}, KeyChar c) ->
      case charToKey c of
        Nothing -> (st, [Beep])
        Just key ->
          case resolveSelection cells (typed ++ [key]) of
            NoMatch -> (st, [Beep])
            Incomplete typed' ->
              (st {stMode = overlay {typedKeys = typed'}}, [])
            Resolved cell -> selectCell cfg st cell
    (overlay@GridOverlay {overlayCells = cells, typedKeys = typed}, MoveKey dir) ->
      case dirToKey dir of
        Just key ->
          case resolveSelection cells (typed ++ [key]) of
            NoMatch -> nudge cfg st dir
            Incomplete typed' ->
              (st {stMode = overlay {typedKeys = typed'}}, [])
            Resolved cell -> selectCell cfg st cell
        Nothing -> nudge cfg st dir
    (GridOverlay {}, Confirm) ->
      case stMode st of
        GridOverlay {overlayCells = cells, typedKeys = typed} ->
          case resolveSelection cells typed of
            Resolved cell -> selectCell cfg st cell
            _ -> (st, [Beep])
        _ -> (st, [Beep])
    _ -> (st, [Beep])

data SelectionResult = NoMatch | Incomplete [Key] | Resolved LabeledCell

resolveSelection :: [LabeledCell] -> [Key] -> SelectionResult
resolveSelection cells typed =
  case filter ((== typed) . cellLabel) cells of
    [cell] -> Resolved cell
    _ ->
      let matches = filter ((typed `isPrefixOf`) . cellLabel) cells
       in case matches of
            [] -> NoMatch
            [cell] -> Resolved cell
            _ -> Incomplete typed

selectCell :: Config -> AppState -> LabeledCell -> (AppState, [Effect])
selectCell cfg st cell =
  case stMode st of
    GridOverlay {overlayLevel = Coarse}
      | cfgAutoFineGrid cfg ->
          enterFineGrid cfg st cell
    _ ->
      let target = clampPoint (stScreen st) (cellTarget cell)
          st' = st {stCursor = target, stMode = Idle}
       in (st', [WarpCursor target, HideOverlay])

exitOverlay :: AppState -> (AppState, [Effect])
exitOverlay st = (st {stMode = Idle}, [HideOverlay])

enterCursorControl :: AppState -> MoveStyle -> (AppState, [Effect])
enterCursorControl st style =
  ( st
      { stMode =
          CursorControl
            { moveStyle = style
            , gridRegion = Nothing
            }
      }
  , []
  )

toggleMoveStyle :: AppState -> (AppState, [Effect])
toggleMoveStyle st =
  case stMode st of
    CursorControl {moveStyle = FreeRange, gridRegion = gr} ->
      (st {stMode = CursorControl GridStep gr}, [])
    CursorControl {gridRegion = gr} ->
      (st {stMode = CursorControl FreeRange gr}, [])
    other -> (st {stMode = other}, [])

moveCursor :: Config -> AppState -> MoveDir -> (AppState, [Effect])
moveCursor cfg st dir =
  case stMode st of
    CursorControl {moveStyle = FreeRange} ->
      nudgeWith (cfgFreeStep cfg) st dir
    CursorControl {moveStyle = GridStep, gridRegion = Just region} ->
      gridStepMove (cfgGridStep cfg) region st dir
    CursorControl {moveStyle = GridStep, gridRegion = Nothing} ->
      nudgeWith (cfgGridStep cfg) st dir
    _ -> nudge cfg st dir

gridStepMove :: Int -> Rect -> AppState -> MoveDir -> (AppState, [Effect])
gridStepMove step region st dir =
  let p' = clampPoint (stScreen st) (applyDir step (stCursor st) dir)
      bounded =
        if contains region p'
          then p'
          else clampToEdge region p'
   in (st {stCursor = bounded}, [WarpCursor bounded])

clampToEdge :: Rect -> Point -> Point
clampToEdge (Rect x y w h) (Point px py) =
  Point (clamp x (x + w - 1) px) (clamp y (y + h - 1) py)
  where
    clamp lo hi v = max lo (min hi v)

applyDir :: Int -> Point -> MoveDir -> Point
applyDir n (Point x y) MoveUp = Point x (y - n)
applyDir n (Point x y) MoveDown = Point x (y + n)
applyDir n (Point x y) MoveLeft = Point (x - n) y
applyDir n (Point x y) MoveRight = Point (x + n) y

nudge :: Config -> AppState -> MoveDir -> (AppState, [Effect])
nudge cfg = nudgeWith (cfgFreeStep cfg)

nudgeWith :: Int -> AppState -> MoveDir -> (AppState, [Effect])
nudgeWith step st dir =
  let p' = clampPoint (stScreen st) (applyDir step (stCursor st) dir)
   in (st {stCursor = p'}, [WarpCursor p'])

dirToKey :: MoveDir -> Maybe Key
dirToKey MoveLeft = Just KeyH
dirToKey MoveDown = Just KeyJ
dirToKey MoveUp = Just KeyK
dirToKey MoveRight = Just KeyL

screenRect :: Screen -> Rect
screenRect (Screen w h) = Rect 0 0 w h
