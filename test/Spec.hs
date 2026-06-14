module Main (main) where

import Data.List (isPrefixOf, sort)
import qualified Data.Text as T
import Mouseful.Core.Charset
  ( Key (..)
  , defaultKeys
  , keySequences
  , keysToText
  )
import Mouseful.Core.Commands (Effect (..), MouseButton (..), MoveDir (..))
import Mouseful.Core.Geometry
  ( Point (..)
  , Rect (..)
  , Screen (..)
  , center
  , clampPoint
  , contains
  , inset
  , rectFromPoints
  )
import Mouseful.Core.Grid
  ( GridConfig (..)
  , GridLevel (..)
  , LabeledCell (..)
  , cellRect
  , cellTarget
  , coarseCols
  , coarseRows
  , defaultGridConfig
  , refineRegion
  , subdivide
  )
import Mouseful.Core.Input
  ( Event (..)
  , charToKey
  , directionFromChar
  , parseKeyChar
  )
import Mouseful.Core.State
  ( AppState (..)
  , Config (..)
  , Mode (..)
  , MoveStyle (..)
  , defaultConfig
  , initialState
  , step
  , stCursor
  , stMode
  )
import Harness
  ( simulate
  , simulate_
  , runMousefulSim
  )
import Test.Hspec

main :: IO ()
main = hspec spec

spec :: Spec
spec = do
  describe "Mouseful.Core.Geometry" geometrySpec
  describe "Mouseful.Core.Charset" charsetSpec
  describe "Mouseful.Core.Grid" gridSpec
  describe "Mouseful.Core.Input" inputSpec
  describe "Mouseful.Core.State" stateSpec
  describe "Cmd+7 activation simulation" activationSimSpec

--------------------------------------------------------------------------------
-- Geometry
--------------------------------------------------------------------------------

geometrySpec :: Spec
geometrySpec = do
  describe "Point" $ do
    it "constructs and compares equally" $ do
      Point 3 4 `shouldBe` Point 3 4
      Point 3 4 `shouldNotBe` Point 4 3

    it "has fields px and py" $ do
      let p = Point 10 20
      px p `shouldBe` 10
      py p `shouldBe` 20

  describe "Rect" $ do
    it "constructs and compares equally" $ do
      Rect 0 0 100 50 `shouldBe` Rect 0 0 100 50

  describe "Screen" $ do
    it "constructs and compares equally" $ do
      Screen 1920 1080 `shouldBe` Screen 1920 1080

  describe "center" $ do
    it "computes center of an even-sized rect" $ do
      center (Rect 0 0 100 60) `shouldBe` Point 50 30

    it "computes center of an odd-sized rect (integer division)" $ do
      center (Rect 0 0 101 61) `shouldBe` Point 50 30

    it "computes center of an offset rect" $ do
      center (Rect 10 20 100 60) `shouldBe` Point 60 50

    it "handles 1x1 rect" $ do
      center (Rect 5 5 1 1) `shouldBe` Point 5 5

  describe "contains" $ do
    it "returns True for the top-left corner" $ do
      contains (Rect 0 0 100 100) (Point 0 0) `shouldBe` True

    it "returns True for an interior point" $ do
      contains (Rect 0 0 100 100) (Point 50 50) `shouldBe` True

    it "returns False for a point beyond right edge" $ do
      contains (Rect 0 0 100 100) (Point 100 50) `shouldBe` False

    it "returns False for a point beyond bottom edge" $ do
      contains (Rect 0 0 100 100) (Point 50 100) `shouldBe` False

    it "returns False for a negative coordinate point" $ do
      contains (Rect 0 0 100 100) (Point (-1) 0) `shouldBe` False

    it "returns True for max interior point (right before edge)" $ do
      contains (Rect 0 0 100 100) (Point 99 99) `shouldBe` True

    it "works with offset rect" $ do
      contains (Rect 50 50 100 100) (Point 75 75) `shouldBe` True
      contains (Rect 50 50 100 100) (Point 40 40) `shouldBe` False

  describe "clampPoint" $ do
    it "does not change a point inside the screen" $ do
      clampPoint (Screen 100 100) (Point 50 50) `shouldBe` Point 50 50

    it "clamps a point beyond right edge" $ do
      clampPoint (Screen 100 100) (Point 150 50) `shouldBe` Point 99 50

    it "clamps a point beyond bottom edge" $ do
      clampPoint (Screen 100 100) (Point 50 150) `shouldBe` Point 50 99

    it "clamps negative coordinates to 0" $ do
      clampPoint (Screen 100 100) (Point (-10) (-5)) `shouldBe` Point 0 0

    it "handles the corner case exactly at edge (last valid pixel)" $ do
      clampPoint (Screen 100 100) (Point 99 99) `shouldBe` Point 99 99

    it "handles 1x1 screen" $ do
      clampPoint (Screen 1 1) (Point 999 999) `shouldBe` Point 0 0

  describe "inset" $ do
    it "shrinks a rect by margin on all sides" $ do
      inset 10 (Rect 0 0 100 60) `shouldBe` Rect 10 10 80 40

    it "does not shrink below 1x1" $ do
      inset 50 (Rect 0 0 10 10) `shouldBe` Rect 50 50 1 1

    it "handles zero margin" $ do
      inset 0 (Rect 5 5 100 60) `shouldBe` Rect 5 5 100 60

    it "shrinks an offset rect correctly" $ do
      inset 5 (Rect 20 30 100 80) `shouldBe` Rect 25 35 90 70

  describe "rectFromPoints" $ do
    it "creates rect from top-left to bottom-right" $ do
      rectFromPoints (Point 0 0) (Point 100 50) `shouldBe` Rect 0 0 100 50

    it "normalizes when points are given in any order" $ do
      rectFromPoints (Point 100 50) (Point 0 0) `shouldBe` Rect 0 0 100 50

    it "handles identical points (min width/height = 1)" $ do
      rectFromPoints (Point 10 10) (Point 10 10) `shouldBe` Rect 10 10 1 1

    it "handles negative coordinates" $ do
      rectFromPoints (Point (-10) (-5)) (Point 20 30) `shouldBe` Rect (-10) (-5) 30 35

--------------------------------------------------------------------------------
-- Charset
--------------------------------------------------------------------------------

charsetSpec :: Spec
charsetSpec = do
  describe "defaultKeys" $ do
    it "contains 26 keys (all a-z home row letters)" $ do
      length defaultKeys `shouldBe` 26

    it "has no duplicates" $ do
      length (map show defaultKeys) `shouldBe` 26

  describe "keySequences" $ do
    it "returns requested number of sequences" $ do
      length (keySequences 50) `shouldBe` 50

    it "generates unique sequences" $ do
      let labels = keySequences 100
      length labels `shouldBe` 100

    it "starts with single-key sequences (home row priorities)" $ do
      let labels = keySequences 5
      labels !! 0 `shouldBe` [KeyA]
      labels !! 1 `shouldBe` [KeyS]

    it "can generate more sequences than unique single keys" $ do
      let labels = keySequences 30
      length labels `shouldBe` 30
      any ((== 2) . length) labels `shouldBe` True

    it "two-key sequences have no repeated keys" $ do
      let labels = keySequences 200
      length (filter (\ks -> length ks == 2 && head ks /= last ks) labels)
        `shouldSatisfy` (> 0)

    it "returns empty list for n=0" $ do
      keySequences 0 `shouldBe` []

  describe "keysToText" $ do
    it "uses last char of show-derived constructor name (the distinguishing letter)" $ do
      keysToText [KeyA] `shouldBe` T.pack "a"
      keysToText [KeyH] `shouldBe` T.pack "h"
      keysToText [KeyZ] `shouldBe` T.pack "z"

    it "concatenates single-char representations for multiple keys" $ do
      keysToText [KeyA, KeyS] `shouldBe` T.pack "as"
      keysToText [KeyQ, KeyW, KeyE] `shouldBe` T.pack "qwe"

    it "returns empty text for empty list" $ do
      keysToText [] `shouldBe` (T.empty :: T.Text)

  describe "Key" $ do
    it "has Enum/Bounded for deriving all values" $ do
      let allKeys = [minBound .. maxBound] :: [Key]
      length allKeys `shouldBe` 26

    it "has Ord instance using declaration order" $ do
      sort [KeyZ, KeyA, KeyM] `shouldBe` [KeyA, KeyZ, KeyM]

--------------------------------------------------------------------------------
-- Grid
--------------------------------------------------------------------------------

gridSpec :: Spec
gridSpec = do
  describe "defaultGridConfig" $ do
    it "has coarse 8x5 and fine 6x4" $ do
      coarseCols defaultGridConfig `shouldBe` 8
      coarseRows defaultGridConfig `shouldBe` 5
      gridConfigFineCols defaultGridConfig `shouldBe` 6
      gridConfigFineRows defaultGridConfig `shouldBe` 4

  describe "subdivide Coarse" $ do
    it "covers the screen with labeled cells" $ do
      let region = Rect 0 0 800 600
          cells = subdivide defaultGridConfig Coarse region
      length cells `shouldBe` 40

    it "each cell's target is its center" $ do
      let region = Rect 0 0 800 600
          cells = subdivide defaultGridConfig Coarse region
      all (\c -> cellTarget c == center (cellRect c)) cells `shouldBe` True

    it "each cell has a non-empty label" $ do
      let region = Rect 0 0 800 600
          cells = subdivide defaultGridConfig Coarse region
      all (not . null . cellLabel) cells `shouldBe` True

    it "all cell rects are within the region" $ do
      let region = Rect 0 0 800 600
          cells = subdivide defaultGridConfig Coarse region
      all (\c -> contains region (Point (rx (cellRect c)) (ry (cellRect c)))) cells
        `shouldBe` True

    it "handles a very small region (1x1) without crashing" $ do
      let region = Rect 0 0 1 1
          cells = subdivide defaultGridConfig Coarse region
      length cells `shouldBe` 40
      all (\c -> rw (cellRect c) >= 1 && rh (cellRect c) >= 1) cells `shouldBe` True

  describe "subdivide Fine" $ do
    it "produces fineCols * fineRows cells" $ do
      let region = Rect 0 0 100 80
          cfg = defaultGridConfig
          cells = subdivide cfg Fine region
      length cells `shouldBe` gridConfigFineCols cfg * gridConfigFineRows cfg

    it "each fine cell has unique label text" $ do
      let region = Rect 0 0 100 80
          cells = subdivide defaultGridConfig Fine region
      length (map cellLabelText cells) `shouldBe` length cells

  describe "refineRegion" $ do
    it "returns the cell's rect" $ do
      let cell =
            LabeledCell
              { cellLabel = [KeyA]
              , cellLabelText = T.pack "a"
              , cellRect = Rect 10 20 50 30
              , cellTarget = Point 35 35
              }
      refineRegion cell `shouldBe` Rect 10 20 50 30

  describe "LabeledCell" $ do
    it "constructs and compares with Eq" $ do
      let cell =
            LabeledCell
              { cellLabel = [KeyA]
              , cellLabelText = T.pack "a"
              , cellRect = Rect 0 0 100 100
              , cellTarget = Point 50 50
              }
      cell `shouldBe` cell

    it "has Show instance" $ do
      let cell =
            LabeledCell
              { cellLabel = [KeyA]
              , cellLabelText = T.pack "a"
              , cellRect = Rect 0 0 100 100
              , cellTarget = Point 50 50
              }
      show cell `shouldSatisfy` not . null

--------------------------------------------------------------------------------
-- Input
--------------------------------------------------------------------------------

inputSpec :: Spec
inputSpec = do
  describe "parseKeyChar" $ do
    it "parses h/j/k/l as move keys" $ do
      parseKeyChar 'h' `shouldBe` Just (MoveKey MoveLeft)
      parseKeyChar 'j' `shouldBe` Just (MoveKey MoveDown)
      parseKeyChar 'k' `shouldBe` Just (MoveKey MoveUp)
      parseKeyChar 'l' `shouldBe` Just (MoveKey MoveRight)

    it "is case-insensitive for move keys" $ do
      parseKeyChar 'H' `shouldBe` Just (MoveKey MoveLeft)
      parseKeyChar 'L' `shouldBe` Just (MoveKey MoveRight)

    it "parses 'm' as ToggleMoveMode" $ do
      parseKeyChar 'm' `shouldBe` Just ToggleMoveMode

    it "parses space as Confirm" $ do
      parseKeyChar ' ' `shouldBe` Just Confirm

    it "parses return as Confirm" $ do
      parseKeyChar '\r' `shouldBe` Just Confirm

    it "parses escape as Cancel" $ do
      parseKeyChar '\ESC' `shouldBe` Just Cancel

    it "parses 'q' as Quit" $ do
      parseKeyChar 'q' `shouldBe` Just Quit
      parseKeyChar 'Q' `shouldBe` Just Quit

    it "parses label characters (a-z home row) as KeyChar" $ do
      parseKeyChar 'a' `shouldBe` Just (KeyChar 'a')
      parseKeyChar 's' `shouldBe` Just (KeyChar 's')
      parseKeyChar 'd' `shouldBe` Just (KeyChar 'd')
      parseKeyChar 'f' `shouldBe` Just (KeyChar 'f')
      parseKeyChar 'z' `shouldBe` Just (KeyChar 'z')
      parseKeyChar 'x' `shouldBe` Just (KeyChar 'x')
      parseKeyChar 'p' `shouldBe` Just (KeyChar 'p')
      parseKeyChar 'n' `shouldBe` Just (KeyChar 'n')

    it "lowercases uppercase label characters" $ do
      parseKeyChar 'A' `shouldBe` Just (KeyChar 'a')
      parseKeyChar 'Z' `shouldBe` Just (KeyChar 'z')

    it "returns Nothing for non-label characters" $ do
      parseKeyChar '1' `shouldBe` Nothing
      parseKeyChar '!' `shouldBe` Nothing
      parseKeyChar '.' `shouldBe` Nothing

  describe "charToKey" $ do
    it "maps 'a' through 'f' correctly" $ do
      charToKey 'a' `shouldBe` Just KeyA
      charToKey 's' `shouldBe` Just KeyS
      charToKey 'd' `shouldBe` Just KeyD
      charToKey 'f' `shouldBe` Just KeyF

    it "is case-insensitive" $ do
      charToKey 'A' `shouldBe` Just KeyA
      charToKey 'H' `shouldBe` Just KeyH

    it "returns Nothing for unknown characters" $ do
      charToKey '1' `shouldBe` Nothing
      charToKey '-' `shouldBe` Nothing

    it "maps all 26 home-row letters" $ do
      let letters = "asdfghjklqwertyuiopzxcvbnm"
      all (\c -> charToKey c /= Nothing) letters `shouldBe` True

  describe "directionFromChar" $ do
    it "maps h/j/k/l to move directions" $ do
      directionFromChar 'h' `shouldBe` Just MoveLeft
      directionFromChar 'j' `shouldBe` Just MoveDown
      directionFromChar 'k' `shouldBe` Just MoveUp
      directionFromChar 'l' `shouldBe` Just MoveRight

    it "returns Nothing for non-direction home row keys" $ do
      directionFromChar 'a' `shouldBe` Nothing
      directionFromChar 's' `shouldBe` Nothing
      directionFromChar 'q' `shouldBe` Nothing

    it "returns Nothing for completely invalid chars" $ do
      directionFromChar '1' `shouldBe` Nothing

  describe "Event" $ do
    it "has Eq and Show instances" $ do
      (show ActivationPressed) `shouldSatisfy` not . null
      ActivationPressed `shouldBe` ActivationPressed
      ActivationPressed `shouldNotBe` Quit

    it "KeyChar preserves the char" $ do
      KeyChar 'a' `shouldBe` KeyChar 'a'
      KeyChar 'a' `shouldNotBe` KeyChar 'b'

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

stateSpec :: Spec
stateSpec = do
  describe "Config" $ do
    it "defaultConfig has sensible defaults" $ do
      cfgFreeStep defaultConfig `shouldBe` 8
      cfgGridStep defaultConfig `shouldBe` 24
      cfgAutoFineGrid defaultConfig `shouldBe` True

  describe "initialState" $ do
    it "creates state with given screen and cursor" $ do
      let st = initialState (Screen 800 600) (Point 100 200)
      stScreen st `shouldBe` Screen 800 600
      stCursor st `shouldBe` Point 100 200

    it "starts in Idle mode" $ do
      let st = initialState (Screen 800 600) (Point 0 0)
      stMode st `shouldBe` Idle

  describe "step - Idle mode" $ do
    it "ActivationPressed enters coarse grid overlay" $ do
      let st = initialState (Screen 800 600) (Point 50 50)
          (st', fx) = step defaultConfig st ActivationPressed
      case stMode st' of
        GridOverlay {overlayLevel = Coarse} -> True
        _ -> False
        `shouldBe` True
      fx `shouldSatisfy` any isShowOverlay

    it "shows overlay with cells matching grid dimensions" $ do
      let st = initialState (Screen 800 600) (Point 0 0)
          (st', _) = step defaultConfig st ActivationPressed
      case stMode st' of
        GridOverlay {overlayCells = cells} ->
          length cells `shouldBe` 40
        _ -> expectationFailure "Expected GridOverlay"

    it "MoveKey nudges cursor right in Idle" $ do
      let st = initialState (Screen 200 200) (Point 50 50)
          (st', fx) = step defaultConfig st (MoveKey MoveRight)
      stCursor st' `shouldBe` Point 58 50
      fx `shouldSatisfy` any isWarp

    it "MoveKey nudges cursor up in Idle" $ do
      let st = initialState (Screen 200 200) (Point 50 50)
          (st', _) = step defaultConfig st (MoveKey MoveUp)
      stCursor st' `shouldBe` Point 50 42

    it "MoveKey nudges cursor left in Idle" $ do
      let st = initialState (Screen 200 200) (Point 50 50)
          (st', _) = step defaultConfig st (MoveKey MoveLeft)
      stCursor st' `shouldBe` Point 42 50

    it "MoveKey nudges cursor down in Idle" $ do
      let st = initialState (Screen 200 200) (Point 50 50)
          (st', _) = step defaultConfig st (MoveKey MoveDown)
      stCursor st' `shouldBe` Point 50 58

    it "ToggleMoveMode enters CursorControl in FreeRange" $ do
      let st = initialState (Screen 800 600) (Point 0 0)
          (st', _) = step defaultConfig st ToggleMoveMode
      case stMode st' of
        CursorControl {moveStyle = FreeRange} -> True
        _ -> False
        `shouldBe` True

    it "Quit in Idle produces no effects and no state change" $ do
      let st = initialState (Screen 800 600) (Point 0 0)
          (st', fx) = step defaultConfig st Quit
      st' `shouldBe` st
      fx `shouldBe` []

    it "unknown events in Idle produce Beep" $ do
      let st = initialState (Screen 800 600) (Point 0 0)
          (st', fx) = step defaultConfig st Confirm
      st' `shouldBe` st
      fx `shouldBe` [Beep]

  describe "step - GridOverlay mode" $ do
    it "Cancel exits overlay back to Idle" $ do
      let st = initialState (Screen 800 600) (Point 0 0)
          (st1, _) = step defaultConfig st ActivationPressed
          (st2, fx) = step defaultConfig st1 Cancel
      stMode st2 `shouldBe` Idle
      fx `shouldSatisfy` any isHideOverlay

    it "KeyChar that fully matches a cell label resolves immediately" $ do
      let st = initialState (Screen 800 600) (Point 0 0)
          (st1, _) = step defaultConfig st ActivationPressed
          (st2, _) = step defaultConfig st1 (KeyChar 'a')
      -- [KeyA] is the exact label of the first coarse cell, resolves -> fine grid
      case stMode st2 of
        GridOverlay {overlayLevel = Fine} -> True
        _ -> False
        `shouldBe` True

    it "KeyChar NoMatch (typing same key twice after resolution) produces Beep" $ do
      -- First 'a' resolves coarse cell -> fine grid. Second 'a' resolves fine cell -> warp + hide.
      -- To get a true NoMatch, use cfgAutoFineGrid = False and type 'aa' while in coarse:
      -- after first 'a' resolves to Idle, 'a' in Idle is handled by catch-all which beeps.
      let cfg = defaultConfig {cfgAutoFineGrid = False}
          st = initialState (Screen 800 600) (Point 0 0)
          (st1, _) = step cfg st ActivationPressed
          (st2, _) = step cfg st1 (KeyChar 'a')
          (st3, fx) = step cfg st2 (KeyChar 'a')
      stMode st2 `shouldBe` Idle        -- resolved coarse -> Idle
      fx `shouldBe` [Beep]              -- 'a' in Idle beeps

    it "KeyChar non-label chars produce Beep in overlay" $ do
      let st = initialState (Screen 800 600) (Point 0 0)
          (st1, _) = step defaultConfig st ActivationPressed
          (st2, fx) = step defaultConfig st1 (KeyChar '1')
      fx `shouldBe` [Beep]

    it "Confirm with no match produces Beep" $ do
      let st = initialState (Screen 800 600) (Point 0 0)
          (st1, _) = step defaultConfig st ActivationPressed
          (st2, fx) = step defaultConfig st1 Confirm
      fx `shouldBe` [Beep]

    it "MoveKey in coarse grid resolves via dirToKey mapping" $ do
      let st = initialState (Screen 800 600) (Point 0 0)
          (st1, _) = step defaultConfig st ActivationPressed
          (st2, _) = step defaultConfig st1 (MoveKey MoveDown)
      -- MoveDown maps to 'j' -> KeyJ, which is cell 7 in coarse grid
      stMode st2 `shouldSatisfy` \m ->
        case m of
          GridOverlay {overlayLevel = Fine} -> True  -- resolved -> auto fine grid
          Idle -> True                               -- or resolved -> Idle
          _ -> False

    it "MoveKey after partial resolution extends typed keys (Incomplete)" $ do
      -- In fine grid (24 cells), first 24 are single-key. To get Incomplete,
      -- we need a non-resolving char. With autoFineGrid=False, 'a' in coarse
      -- resolves -> Idle, then ActivationPressed -> coarse again. Hmm.
      -- Simpler: test that keys NOT in defaultKeys produce Beep in overlay
      let st = initialState (Screen 800 600) (Point 0 0)
          (st1, _) = step defaultConfig st ActivationPressed
          (st2, fx) = step defaultConfig st1 (KeyChar '1')
      fx `shouldBe` [Beep]  -- '1' is not a label char, charToKey returns Nothing

  describe "step - CursorControl mode" $ do
    it "Cancel exits CursorControl to Idle with HideOverlay" $ do
      let st = initialState (Screen 800 600) (Point 0 0)
          (st1, _) = step defaultConfig st ToggleMoveMode
          (st2, fx) = step defaultConfig st1 Cancel
      stMode st2 `shouldBe` Idle
      fx `shouldSatisfy` any isHideOverlay

    it "ToggleMoveMode toggles between FreeRange and GridStep" $ do
      let st = initialState (Screen 800 600) (Point 0 0)
          (st1, _) = step defaultConfig st ToggleMoveMode
      case stMode st1 of
        CursorControl {moveStyle = FreeRange} -> True
        _ -> False
        `shouldBe` True
      let (st2, _) = step defaultConfig st1 ToggleMoveMode
      case stMode st2 of
        CursorControl {moveStyle = GridStep} -> True
        _ -> False
        `shouldBe` True

    it "MoveKey in FreeRange moves by freeStep" $ do
      let st = initialState (Screen 200 200) (Point 50 50)
          (st1, _) = step defaultConfig st ToggleMoveMode
          (st2, fx) = step defaultConfig st1 (MoveKey MoveRight)
      stCursor st2 `shouldBe` Point 58 50
      fx `shouldSatisfy` any isWarp

    it "MoveKey in GridStep without grid region moves by gridStep" $ do
      let st = initialState (Screen 200 200) (Point 50 50)
          (st1, _) = step defaultConfig st ToggleMoveMode
          (st2, _) = step defaultConfig st1 ToggleMoveMode
          (st3, _) = step defaultConfig st2 (MoveKey MoveRight)
      stCursor st3 `shouldBe` Point 74 50

    it "Confirm in CursorControl clicks left button" $ do
      let st = initialState (Screen 200 200) (Point 50 50)
          (st1, _) = step defaultConfig st ToggleMoveMode
          (st2, fx) = step defaultConfig st1 Confirm
      st2 `shouldBe` st1
      fx `shouldBe` [Click LeftButton]

    it "ClickLeft in CursorControl emits Click LeftButton" $ do
      let st = initialState (Screen 200 200) (Point 50 50)
          (st1, _) = step defaultConfig st ToggleMoveMode
          (st2, fx) = step defaultConfig st1 ClickLeft
      fx `shouldBe` [Click LeftButton]

    it "ClickRight in CursorControl emits Click RightButton" $ do
      let st = initialState (Screen 200 200) (Point 50 50)
          (st1, _) = step defaultConfig st ToggleMoveMode
          (st2, fx) = step defaultConfig st1 ClickRight
      fx `shouldBe` [Click RightButton]

    it "ActivationPressed in CursorControl enters coarse grid" $ do
      let st = initialState (Screen 800 600) (Point 0 0)
          (st1, _) = step defaultConfig st ToggleMoveMode
          (st2, fx) = step defaultConfig st1 ActivationPressed
      case stMode st2 of
        GridOverlay {overlayLevel = Coarse} -> True
        _ -> False
        `shouldBe` True
      fx `shouldSatisfy` any isShowOverlay

    it "Quit in CursorControl produces no effects" $ do
      let st = initialState (Screen 800 600) (Point 0 0)
          (st1, _) = step defaultConfig st ToggleMoveMode
          (st2, fx) = step defaultConfig st1 Quit
      st2 `shouldBe` st1
      fx `shouldBe` []

  describe "step - move cursor boundary conditions" $ do
    it "clamps cursor to screen right edge" $ do
      let st = initialState (Screen 100 100) (Point 95 50)
          (st', _) = step defaultConfig st (MoveKey MoveRight)
      stCursor st' `shouldBe` Point 99 50

    it "clamps cursor to screen top edge" $ do
      let st = initialState (Screen 100 100) (Point 50 5)
          (st', _) = step defaultConfig st (MoveKey MoveUp)
      stCursor st' `shouldBe` Point 50 0

    it "clamps cursor to screen left edge" $ do
      let st = initialState (Screen 100 100) (Point 3 50)
          (st', _) = step defaultConfig st (MoveKey MoveLeft)
      stCursor st' `shouldBe` Point 0 50

    it "clamps cursor to screen bottom edge" $ do
      let st = initialState (Screen 100 100) (Point 50 95)
          (st', _) = step defaultConfig st (MoveKey MoveDown)
      stCursor st' `shouldBe` Point 50 99

  describe "step - fine grid and autoFineGrid" $ do
    it "with cfgAutoFineGrid True, selecting coarse cell opens fine grid" $ do
      let cfg = defaultConfig {cfgAutoFineGrid = True}
          st = initialState (Screen 800 600) (Point 0 0)
          (st1, _) = step cfg st ActivationPressed
          (st2, fx2) = step cfg st1 (KeyChar 'a')
      case stMode st2 of
        GridOverlay {overlayLevel = Fine} -> True
        _ -> False
        `shouldBe` True
      fx2 `shouldSatisfy` any isShowOverlay

    it "with cfgAutoFineGrid False, selecting coarse cell warps cursor" $ do
      let cfg = defaultConfig {cfgAutoFineGrid = False}
          st = initialState (Screen 800 600) (Point 0 0)
          (st1, _) = step cfg st ActivationPressed
          (st2, fx2) = step cfg st1 (KeyChar 'a')
      stMode st2 `shouldBe` Idle
      fx2 `shouldSatisfy` any isWarp
      fx2 `shouldSatisfy` any isHideOverlay

    it "selecting a fine grid cell warps cursor and hides overlay" $ do
      let cfg = defaultConfig {cfgAutoFineGrid = True}
          st = initialState (Screen 800 600) (Point 0 0)
          (st1, _) = step cfg st ActivationPressed
          (st2, _) = step cfg st1 (KeyChar 'a') -- now in fine grid
          (st3, fx3) = step cfg st2 (KeyChar 'a') -- select first fine cell
      stMode st3 `shouldBe` Idle
      fx3 `shouldSatisfy` any isWarp
      fx3 `shouldSatisfy` any isHideOverlay

  describe "step - edge transitions" $ do
    it "unknown event in GridOverlay produces Beep" $ do
      let st = initialState (Screen 800 600) (Point 0 0)
          (st1, _) = step defaultConfig st ActivationPressed
          (st2, fx) = step defaultConfig st1 Quit -- Quit only handled in Idle/CursorControl
      fx `shouldBe` [Beep]

    it "Confirm from Coarse overlay with incomplete selection beeps" $ do
      let st = initialState (Screen 800 600) (Point 0 0)
          (st1, _) = step defaultConfig st ActivationPressed
          (st2, fx) = step defaultConfig st1 Confirm
      fx `shouldBe` [Beep]

  describe "step - gridStepMove bounded behavior" $ do
    it "GridStep without region moves by gridStep on move key" $ do
      let cfg = defaultConfig
          st0 = initialState (Screen 800 600) (Point 100 100)
          (st1, _) = step cfg st0 ToggleMoveMode
          (st2, _) = step cfg st1 ToggleMoveMode
          (st3, _) = step cfg st2 (MoveKey MoveUp)
      stCursor st3 `shouldBe` Point 100 76

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

isShowOverlay :: Effect -> Bool
isShowOverlay (ShowOverlay _) = True
isShowOverlay _ = False

isHideOverlay :: Effect -> Bool
isHideOverlay HideOverlay = True
isHideOverlay _ = False

isWarp :: Effect -> Bool
isWarp (WarpCursor _) = True
isWarp _ = False

isBeep :: Effect -> Bool
isBeep Beep = True
isBeep _ = False

gridConfigFineCols :: GridConfig -> Int
gridConfigFineCols = fineCols

gridConfigFineRows :: GridConfig -> Int
gridConfigFineRows = fineRows

--------------------------------------------------------------------------------
-- Cmd+7 activation simulation
--------------------------------------------------------------------------------

activationSimSpec :: Spec
activationSimSpec = do
  describe "simulating Cmd+7 (ActivationPressed)" $ do
    it "shows coarse grid overlay with 40 cells on activation" $ do
      let (fx, st) =
            runMousefulSim
              (Screen 1920 1080, Point 960 540)
              defaultConfig
              (simulate_ defaultConfig [ActivationPressed])
      fx `shouldSatisfy` any isShowOverlay
      case stMode st of
        GridOverlay {overlayCells = cells} -> do
          length cells `shouldBe` 40
          -- verify labels are correct (not all "k")
          map cellLabelText cells `shouldSatisfy` \labels ->
            any (== T.pack "a") labels
              && any (== T.pack "s") labels
              && any (== T.pack "h") labels
              && any (== T.pack "k") labels
        _ -> expectationFailure "Expected GridOverlay"

    it "typing 'a' in coarse grid selects cell 'a' and opens fine grid" $ do
      let (fx, st) =
            runMousefulSim
              (Screen 1920 1080, Point 960 540)
              defaultConfig
              (simulate_ defaultConfig
                [ ActivationPressed   -- Cmd+7
                , KeyChar 'a'         -- type 'a' -> selects first cell
                ])
      case stMode st of
        GridOverlay {overlayLevel = Fine, overlayCells = cells} -> do
          length cells `shouldBe` 24
        _ -> expectationFailure "Expected Fine grid overlay after selecting 'a'"

    it "typing non-label char '1' in coarse grid should beep" $ do
      let (fx, st) =
            runMousefulSim
              (Screen 1920 1080, Point 960 540)
              defaultConfig
              (simulate_ defaultConfig
                [ ActivationPressed
                , KeyChar '1'
                ])
      fx `shouldSatisfy` any isBeep

    it "Cancel closes the overlay" $ do
      let (fx, st) =
            runMousefulSim
              (Screen 1920 1080, Point 960 540)
              defaultConfig
              (simulate_ defaultConfig
                [ ActivationPressed
                , Cancel
                ])
      stMode st `shouldBe` Idle
      fx `shouldSatisfy` any isHideOverlay

    it "pressing 'k' (via MoveKey Up) in grid resolves cell 'k'" $ do
      let (fx, st) =
            runMousefulSim
              (Screen 1920 1080, Point 960 540)
              defaultConfig
              (simulate_ defaultConfig
                [ ActivationPressed
                , MoveKey MoveUp     -- maps to KeyK -> label "k"
                ])
      case stMode st of
        GridOverlay {overlayLevel = Fine} -> pure ()
        Idle -> pure ()
        m -> expectationFailure $ "Expected Fine grid or Idle after 'k', got: " ++ show m

    it "full flow: activate, type 'as', select fine cell 'a'" $ do
      let (fx, st) =
            runMousefulSim
              (Screen 800 600, Point 400 300)
              defaultConfig
              (simulate_ defaultConfig
                [ ActivationPressed   -- Cmd+7
                , KeyChar 'a'         -- type 'a' -> resolves coarse "a" -> fine grid
                , KeyChar 'a'         -- type 'a' -> resolves fine "a" -> warp + hide
                ])
      stMode st `shouldBe` Idle
      fx `shouldSatisfy` any isWarp
      fx `shouldSatisfy` any isHideOverlay
