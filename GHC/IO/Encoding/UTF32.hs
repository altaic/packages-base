{-# LANGUAGE NoImplicitPrelude
           , BangPatterns
           , NondecreasingIndentation
           , MagicHash
  #-}
{-# OPTIONS_GHC  -funbox-strict-fields #-}

-----------------------------------------------------------------------------
-- |
-- Module      :  GHC.IO.Encoding.UTF32
-- Copyright   :  (c) The University of Glasgow, 2009
-- License     :  see libraries/base/LICENSE
-- 
-- Maintainer  :  libraries@haskell.org
-- Stability   :  internal
-- Portability :  non-portable
--
-- UTF-32 Codecs for the IO library
--
-- Portions Copyright   : (c) Tom Harper 2008-2009,
--                        (c) Bryan O'Sullivan 2009,
--                        (c) Duncan Coutts 2009
--
-----------------------------------------------------------------------------

module GHC.IO.Encoding.UTF32 (
  utf32,
  utf32_decode,
  utf32_encode,

  utf32be,
  utf32be_decode,
  utf32be_encode,

  utf32le,
  utf32le_decode,
  utf32le_encode,
  ) where

import GHC.Base
import GHC.Real
import GHC.Num
-- import GHC.IO
import GHC.IO.Exception
import GHC.IO.Buffer
import GHC.IO.Encoding.Types
import GHC.Word
import Data.Bits
import Data.Maybe
import GHC.IORef

-- -----------------------------------------------------------------------------
-- The UTF-32 codec: either UTF-32BE or UTF-32LE with a BOM

utf32  :: TextEncoding
utf32 = TextEncoding { textEncodingName = "UTF-32",
                       mkTextDecoder = utf32_DF,
 	               mkTextEncoder = utf32_EF }

utf32_DF :: IO (TextDecoder (Maybe DecodeBuffer))
utf32_DF = do
  seen_bom <- newIORef Nothing
  return (BufferCodec {
             encode   = utf32_decode seen_bom,
             close    = return (),
             getState = readIORef seen_bom,
             setState = writeIORef seen_bom
          })

utf32_EF :: IO (TextEncoder Bool)
utf32_EF = do
  done_bom <- newIORef False
  return (BufferCodec {
             encode   = utf32_encode done_bom,
             close    = return (),
             getState = readIORef done_bom,
             setState = writeIORef done_bom
          })

utf32_encode :: IORef Bool -> EncodeBuffer
utf32_encode done_bom input
  output@Buffer{ bufRaw=oraw, bufL=_, bufR=ow, bufSize=os }
 = do
  b <- readIORef done_bom
  if b then utf32_native_encode input output
       else if os - ow < 4
               then return (input,output)
               else do
                    writeIORef done_bom True
                    writeWord8Buf oraw ow     bom0
                    writeWord8Buf oraw (ow+1) bom1
                    writeWord8Buf oraw (ow+2) bom2
                    writeWord8Buf oraw (ow+3) bom3
                    utf32_native_encode input output{ bufR = ow+4 }

utf32_decode :: IORef (Maybe DecodeBuffer) -> DecodeBuffer
utf32_decode seen_bom
  input@Buffer{  bufRaw=iraw, bufL=ir, bufR=iw,  bufSize=_  }
  output
 = do
   mb <- readIORef seen_bom
   case mb of
     Just decode -> decode input output
     Nothing ->
       if iw - ir < 4 then return (input,output) else do
       c0 <- readWord8Buf iraw ir
       c1 <- readWord8Buf iraw (ir+1)
       c2 <- readWord8Buf iraw (ir+2)
       c3 <- readWord8Buf iraw (ir+3)
       case () of
        _ | c0 == bom0 && c1 == bom1 && c2 == bom2 && c3 == bom3 -> do
               writeIORef seen_bom (Just utf32be_decode)
               utf32be_decode input{ bufL= ir+4 } output
        _ | c0 == bom3 && c1 == bom2 && c2 == bom1 && c3 == bom0 -> do
               writeIORef seen_bom (Just utf32le_decode)
               utf32le_decode input{ bufL= ir+4 } output
          | otherwise -> do
               writeIORef seen_bom (Just utf32_native_decode)
               utf32_native_decode input output


bom0, bom1, bom2, bom3 :: Word8
bom0 = 0
bom1 = 0
bom2 = 0xfe
bom3 = 0xff

-- choose UTF-32BE by default for UTF-32 output
utf32_native_decode :: DecodeBuffer
utf32_native_decode = utf32be_decode

utf32_native_encode :: EncodeBuffer
utf32_native_encode = utf32be_encode

-- -----------------------------------------------------------------------------
-- UTF32LE and UTF32BE

utf32be :: TextEncoding
utf32be = TextEncoding { textEncodingName = "UTF-32BE",
                         mkTextDecoder = utf32be_DF,
 	                 mkTextEncoder = utf32be_EF }

utf32be_DF :: IO (TextDecoder ())
utf32be_DF =
  return (BufferCodec {
             encode   = utf32be_decode,
             close    = return (),
             getState = return (),
             setState = const $ return ()
          })

utf32be_EF :: IO (TextEncoder ())
utf32be_EF =
  return (BufferCodec {
             encode   = utf32be_encode,
             close    = return (),
             getState = return (),
             setState = const $ return ()
          })


utf32le :: TextEncoding
utf32le = TextEncoding { textEncodingName = "UTF-32LE",
                         mkTextDecoder = utf32le_DF,
 	                 mkTextEncoder = utf32le_EF }

utf32le_DF :: IO (TextDecoder ())
utf32le_DF =
  return (BufferCodec {
             encode   = utf32le_decode,
             close    = return (),
             getState = return (),
             setState = const $ return ()
          })

utf32le_EF :: IO (TextEncoder ())
utf32le_EF =
  return (BufferCodec {
             encode   = utf32le_encode,
             close    = return (),
             getState = return (),
             setState = const $ return ()
          })


utf32be_decode :: DecodeBuffer
utf32be_decode 
  input@Buffer{  bufRaw=iraw, bufL=ir0, bufR=iw,  bufSize=_  }
  output@Buffer{ bufRaw=oraw, bufL=_,   bufR=ow0, bufSize=os }
 = let 
       loop !ir !ow
         | ow >= os || iw - ir < 4 =  done ir ow
         | otherwise = do
              c0 <- readWord8Buf iraw ir
              c1 <- readWord8Buf iraw (ir+1)
              c2 <- readWord8Buf iraw (ir+2)
              c3 <- readWord8Buf iraw (ir+3)
              let x1 = chr4 c0 c1 c2 c3
              if not (validate x1) then invalid else do
              ow' <- writeCharBuf oraw ow x1
              loop (ir+4) ow'
         where
           invalid = if ir > ir0 then done ir ow else ioe_decodingError

       -- lambda-lifted, to avoid thunks being built in the inner-loop:
       done !ir !ow = return (if ir == iw then input{ bufL=0, bufR=0 }
                                          else input{ bufL=ir },
                         output{ bufR=ow })
    in
    loop ir0 ow0

utf32le_decode :: DecodeBuffer
utf32le_decode 
  input@Buffer{  bufRaw=iraw, bufL=ir0, bufR=iw,  bufSize=_  }
  output@Buffer{ bufRaw=oraw, bufL=_,   bufR=ow0, bufSize=os }
 = let 
       loop !ir !ow
         | ow >= os || iw - ir < 4 =  done ir ow
         | otherwise = do
              c0 <- readWord8Buf iraw ir
              c1 <- readWord8Buf iraw (ir+1)
              c2 <- readWord8Buf iraw (ir+2)
              c3 <- readWord8Buf iraw (ir+3)
              let x1 = chr4 c3 c2 c1 c0
              if not (validate x1) then invalid else do
              ow' <- writeCharBuf oraw ow x1
              loop (ir+4) ow'
         where
           invalid = if ir > ir0 then done ir ow else ioe_decodingError

       -- lambda-lifted, to avoid thunks being built in the inner-loop:
       done !ir !ow = return (if ir == iw then input{ bufL=0, bufR=0 }
                                          else input{ bufL=ir },
                         output{ bufR=ow })
    in
    loop ir0 ow0

ioe_decodingError :: IO a
ioe_decodingError = ioException
     (IOError Nothing InvalidArgument "utf32_decode"
          "invalid UTF-32 byte sequence" Nothing Nothing)

utf32be_encode :: EncodeBuffer
utf32be_encode
  input@Buffer{  bufRaw=iraw, bufL=ir0, bufR=iw,  bufSize=_  }
  output@Buffer{ bufRaw=oraw, bufL=_,   bufR=ow0, bufSize=os }
 = let 
      done !ir !ow = return (if ir == iw then input{ bufL=0, bufR=0 }
                                         else input{ bufL=ir },
                             output{ bufR=ow })
      loop !ir !ow
        | ir >= iw     =  done ir ow
        | os - ow < 4  =  done ir ow
        | otherwise = do
           (c,ir') <- readCharBuf iraw ir
           let (c0,c1,c2,c3) = ord4 c
           writeWord8Buf oraw ow     c0
           writeWord8Buf oraw (ow+1) c1
           writeWord8Buf oraw (ow+2) c2
           writeWord8Buf oraw (ow+3) c3
           loop ir' (ow+4)
    in
    loop ir0 ow0

utf32le_encode :: EncodeBuffer
utf32le_encode
  input@Buffer{  bufRaw=iraw, bufL=ir0, bufR=iw,  bufSize=_  }
  output@Buffer{ bufRaw=oraw, bufL=_,   bufR=ow0, bufSize=os }
 = let
      done !ir !ow = return (if ir == iw then input{ bufL=0, bufR=0 }
                                         else input{ bufL=ir },
                             output{ bufR=ow })
      loop !ir !ow
        | ir >= iw     =  done ir ow
        | os - ow < 4  =  done ir ow
        | otherwise = do
           (c,ir') <- readCharBuf iraw ir
           let (c0,c1,c2,c3) = ord4 c
           writeWord8Buf oraw ow     c3
           writeWord8Buf oraw (ow+1) c2
           writeWord8Buf oraw (ow+2) c1
           writeWord8Buf oraw (ow+3) c0
           loop ir' (ow+4)
    in
    loop ir0 ow0

chr4 :: Word8 -> Word8 -> Word8 -> Word8 -> Char
chr4 (W8# x1#) (W8# x2#) (W8# x3#) (W8# x4#) =
    C# (chr# (z1# +# z2# +# z3# +# z4#))
    where
      !y1# = word2Int# x1#
      !y2# = word2Int# x2#
      !y3# = word2Int# x3#
      !y4# = word2Int# x4#
      !z1# = uncheckedIShiftL# y1# 24#
      !z2# = uncheckedIShiftL# y2# 16#
      !z3# = uncheckedIShiftL# y3# 8#
      !z4# = y4#
{-# INLINE chr4 #-}

ord4 :: Char -> (Word8,Word8,Word8,Word8)
ord4 c = (fromIntegral (x `shiftR` 24), 
          fromIntegral (x `shiftR` 16), 
          fromIntegral (x `shiftR` 8),
          fromIntegral x)
  where
    x = ord c
{-# INLINE ord4 #-}


validate    :: Char -> Bool
validate c = (x1 >= 0x0 && x1 < 0xD800) || (x1 > 0xDFFF && x1 <= 0x10FFFF)
   where x1 = ord c
{-# INLINE validate #-}
