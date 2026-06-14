{-# LANGUAGE CApiFFI #-}

module Mouseful.Platform.MacOS.FFI
  ( MLEventType (..)
  , MLEvent (..)
  , MLGridCell (..)
  , mousefulInit
  , mousefulShutdown
  , mousefulLastError
  , mousefulScreenWidth
  , mousefulScreenHeight
  , mousefulCursorX
  , mousefulCursorY
  , mousefulWarpCursor
  , mousefulClick
  , mousefulBeep
  , mousefulShowOverlay
  , mousefulHideOverlay
  , mousefulWaitEvent
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

foreign import ccall "mouseful_init" c_mouseful_init :: IO CInt
foreign import ccall "mouseful_shutdown" c_mouseful_shutdown :: IO ()
foreign import ccall "mouseful_last_error" c_mouseful_last_error :: IO CString
foreign import ccall "mouseful_screen_width" c_mouseful_screen_width :: IO CInt
foreign import ccall "mouseful_screen_height" c_mouseful_screen_height :: IO CInt
foreign import ccall "mouseful_cursor_x" c_mouseful_cursor_x :: IO CInt
foreign import ccall "mouseful_cursor_y" c_mouseful_cursor_y :: IO CInt
foreign import ccall "mouseful_warp_cursor" c_mouseful_warp_cursor :: CInt -> CInt -> IO ()
foreign import ccall "mouseful_click" c_mouseful_click :: CInt -> IO ()
foreign import ccall "mouseful_beep" c_mouseful_beep :: IO ()
foreign import ccall "mouseful_show_overlay"
  c_mouseful_show_overlay :: Ptr CMLGridCell -> CSize -> IO ()
foreign import ccall "mouseful_hide_overlay" c_mouseful_hide_overlay :: IO ()
foreign import ccall "mouseful_wait_event"
  c_mouseful_wait_event :: Ptr CMLEvent -> IO ()

mousefulInit :: IO ()
mousefulInit = do
  rc <- c_mouseful_init
  when (rc /= 0) $ do
    msg <- mousefulLastError
    fail msg

mousefulShutdown :: IO ()
mousefulShutdown = c_mouseful_shutdown

mousefulLastError :: IO String
mousefulLastError = peekCString =<< c_mouseful_last_error

mousefulScreenWidth :: IO Int
mousefulScreenWidth = fromIntegral <$> c_mouseful_screen_width

mousefulScreenHeight :: IO Int
mousefulScreenHeight = fromIntegral <$> c_mouseful_screen_height

mousefulCursorX :: IO Int
mousefulCursorX = fromIntegral <$> c_mouseful_cursor_x

mousefulCursorY :: IO Int
mousefulCursorY = fromIntegral <$> c_mouseful_cursor_y

mousefulWarpCursor :: Int -> Int -> IO ()
mousefulWarpCursor x y =
  c_mouseful_warp_cursor (fromIntegral x) (fromIntegral y)

mousefulClick :: Int -> IO ()
mousefulClick btn = c_mouseful_click (fromIntegral btn)

mousefulBeep :: IO ()
mousefulBeep = c_mouseful_beep

mousefulShowOverlay :: [MLGridCell] -> IO ()
mousefulShowOverlay [] = c_mouseful_show_overlay nullPtr 0
mousefulShowOverlay cells =
  allocaArray (length cells) $ \ptr -> do
    mapM_ (uncurry (pokeGridCell ptr)) (zip [0 ..] cells)
    c_mouseful_show_overlay ptr (fromIntegral (length cells))

mousefulHideOverlay :: IO ()
mousefulHideOverlay = c_mouseful_hide_overlay

mousefulWaitEvent :: IO MLEvent
mousefulWaitEvent = alloca $ \ptr -> do
  c_mouseful_wait_event ptr
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
