{-# LANGUAGE CApiFFI #-}

module Mouseless.Platform.MacOS.FFI
  ( MLEventType (..)
  , MLEvent (..)
  , MLGridCell (..)
  , mouselessInit
  , mouselessShutdown
  , mouselessLastError
  , mouselessScreenWidth
  , mouselessScreenHeight
  , mouselessCursorX
  , mouselessCursorY
  , mouselessWarpCursor
  , mouselessClick
  , mouselessBeep
  , mouselessShowOverlay
  , mouselessHideOverlay
  , mouselessWaitEvent
  ) where

import Control.Monad (mapM_, when)
import Data.Char (chr)
import Foreign (Ptr, Storable (..), alloca, allocaArray, nullPtr, peek, plusPtr)
import Foreign.C.String (CString, peekCString)
import Foreign.C.Types (CChar, CInt (..), CSize (..))

data MLEventType = MLNone | MLActivation | MLKey
  deriving (Eq, Show)

data MLEvent = MLEvent
  { mlEventType :: !MLEventType
  , mlEventKey :: !Char
  }
  deriving (Eq, Show)

data MLGridCell = MLGridCell
  { mlCellX :: !Int
  , mlCellY :: !Int
  , mlCellW :: !Int
  , mlCellH :: !Int
  , mlCellLabel :: !String
  }
  deriving (Eq, Show)

data CMLEvent = CMLEvent
  { cmlType :: !CInt
  , cmlKey :: !CChar
  }

instance Storable CMLEvent where
  sizeOf _ = 8
  alignment _ = 4
  peek ptr = do
    t <- peekByteOff ptr 0
    k <- peekByteOff ptr 4
    pure CMLEvent {cmlType = t, cmlKey = k}
  poke ptr (CMLEvent t k) = do
    pokeByteOff ptr 0 t
    pokeByteOff ptr 4 k

data CMLGridCell

instance Storable CMLGridCell where
  sizeOf _ = 32
  alignment _ = 4

foreign import ccall "mouseless_init" c_mouseless_init :: IO CInt
foreign import ccall "mouseless_shutdown" c_mouseless_shutdown :: IO ()
foreign import ccall "mouseless_last_error" c_mouseless_last_error :: IO CString
foreign import ccall "mouseless_screen_width" c_mouseless_screen_width :: IO CInt
foreign import ccall "mouseless_screen_height" c_mouseless_screen_height :: IO CInt
foreign import ccall "mouseless_cursor_x" c_mouseless_cursor_x :: IO CInt
foreign import ccall "mouseless_cursor_y" c_mouseless_cursor_y :: IO CInt
foreign import ccall "mouseless_warp_cursor" c_mouseless_warp_cursor :: CInt -> CInt -> IO ()
foreign import ccall "mouseless_click" c_mouseless_click :: CInt -> IO ()
foreign import ccall "mouseless_beep" c_mouseless_beep :: IO ()
foreign import ccall "mouseless_show_overlay"
  c_mouseless_show_overlay :: Ptr CMLGridCell -> CSize -> IO ()
foreign import ccall "mouseless_hide_overlay" c_mouseless_hide_overlay :: IO ()
foreign import ccall "mouseless_wait_event"
  c_mouseless_wait_event :: Ptr CMLEvent -> IO ()

mouselessInit :: IO ()
mouselessInit = do
  rc <- c_mouseless_init
  when (rc /= 0) $ do
    msg <- mouselessLastError
    fail msg

mouselessShutdown :: IO ()
mouselessShutdown = c_mouseless_shutdown

mouselessLastError :: IO String
mouselessLastError = peekCString =<< c_mouseless_last_error

mouselessScreenWidth :: IO Int
mouselessScreenWidth = fromIntegral <$> c_mouseless_screen_width

mouselessScreenHeight :: IO Int
mouselessScreenHeight = fromIntegral <$> c_mouseless_screen_height

mouselessCursorX :: IO Int
mouselessCursorX = fromIntegral <$> c_mouseless_cursor_x

mouselessCursorY :: IO Int
mouselessCursorY = fromIntegral <$> c_mouseless_cursor_y

mouselessWarpCursor :: Int -> Int -> IO ()
mouselessWarpCursor x y =
  c_mouseless_warp_cursor (fromIntegral x) (fromIntegral y)

mouselessClick :: Int -> IO ()
mouselessClick btn = c_mouseless_click (fromIntegral btn)

mouselessBeep :: IO ()
mouselessBeep = c_mouseless_beep

mouselessShowOverlay :: [MLGridCell] -> IO ()
mouselessShowOverlay [] = c_mouseless_show_overlay nullPtr 0
mouselessShowOverlay cells =
  allocaArray (length cells) $ \ptr -> do
    mapM_ (uncurry (pokeGridCell ptr)) (zip [0 ..] cells)
    c_mouseless_show_overlay ptr (fromIntegral (length cells))

mouselessHideOverlay :: IO ()
mouselessHideOverlay = c_mouseless_hide_overlay

mouselessWaitEvent :: IO MLEvent
mouselessWaitEvent = alloca $ \ptr -> do
  c_mouseless_wait_event ptr
  raw <- peek ptr
  pure
    MLEvent
      { mlEventType = decodeType (cmlType raw)
      , mlEventKey = chr (fromIntegral (cmlKey raw) :: Int)
      }
  where
    decodeType 1 = MLActivation
    decodeType 2 = MLKey
    decodeType _ = MLNone

pokeGridCell :: Ptr CMLGridCell -> Int -> MLGridCell -> IO ()
pokeGridCell base idx (MLGridCell x y w h lbl) = do
  let ptr = base `plusPtr` (idx * sizeOf (undefined :: CMLGridCell))
  pokeByteOff ptr 0 (fromIntegral x :: CInt)
  pokeByteOff ptr 4 (fromIntegral y :: CInt)
  pokeByteOff ptr 8 (fromIntegral w :: CInt)
  pokeByteOff ptr 12 (fromIntegral h :: CInt)
  mapM_ (pokeLabelByte ptr) (zip [0 ..] (take 15 lbl))
  pokeByteOff ptr (16 + min 15 (length lbl)) (0 :: CChar)

pokeLabelByte :: Ptr CMLGridCell -> (Int, Char) -> IO ()
pokeLabelByte ptr (off, c) =
  pokeByteOff ptr (16 + off) (fromIntegral (fromEnum c) :: CChar)
