import Mouseless.Core.Charset (keySequences, keysToText)
import Mouseless.Core.Commands (Effect (..), MoveDir (..))
import Mouseless.Core.Geometry (Point (..), Rect (..), Screen (..), center)
import Mouseless.Core.Grid
  ( GridLevel (..)
  , cellRect
  , cellTarget
  , coarseCols
  , coarseRows
  , defaultGridConfig
  , subdivide
  )
import Mouseless.Core.Input (Event (..))
import Mouseless.Core.State
  ( AppState (..)
  , Config (..)
  , Mode (..)
  , defaultConfig
  , initialState
  , step
  , stCursor
  , stMode
  )
import Test.Hspec

main :: IO ()
main = hspec spec

spec :: Spec
spec = do
  describe "Charset.keySequences" $ do
    it "assigns unique labels" $ do
      let labels = keySequences 40
      length labels `shouldBe` 40
      length (map keysToText labels) `shouldBe` 40

  describe "Grid.subdivide" $ do
    it "covers the screen with labeled cells" $ do
      let region = Rect 0 0 800 600
          cells = subdivide defaultGridConfig Coarse region
      length cells `shouldBe` coarseCols defaultGridConfig * coarseRows defaultGridConfig
      head cells `shouldSatisfy` ((== center (cellRect (head cells))) . cellTarget)

  describe "State.step" $ do
    it "shows coarse overlay on activation" $ do
      let st = initialState (Screen 100 100) (Point 50 50)
          (_, fx) = step defaultConfig st ActivationPressed
      fx `shouldSatisfy` any isShowOverlay

    it "opens fine grid after a coarse label resolves" $ do
      let cfg = defaultConfig {cfgAutoFineGrid = True}
          st0 = initialState (Screen 800 600) (Point 0 0)
          (st1, _) = step cfg st0 ActivationPressed
          (st2, fx2) = step cfg st1 (KeyChar 'a')
      fx2 `shouldSatisfy` any isShowOverlay
      stMode st2 `shouldSatisfy` isFineOverlay

    it "nudges cursor with hjkl in idle mode" $ do
      let st = initialState (Screen 200 200) (Point 50 50)
          (st', fx) = step defaultConfig st (MoveKey MoveRight)
      stCursor st' `shouldBe` Point 58 50
      fx `shouldSatisfy` any isWarp

isShowOverlay :: Effect -> Bool
isShowOverlay (ShowOverlay _) = True
isShowOverlay _ = False

isWarp :: Effect -> Bool
isWarp (WarpCursor _) = True
isWarp _ = False

isFineOverlay :: Mode -> Bool
isFineOverlay GridOverlay {overlayLevel = Fine} = True
isFineOverlay _ = False

execEffects :: AppState -> [Effect] -> AppState
execEffects st fx =
  foldl apply st fx
  where
    apply s (WarpCursor p) = s {stCursor = p}
    apply s _ = s
