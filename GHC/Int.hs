{-# LANGUAGE CPP, NoImplicitPrelude, BangPatterns, MagicHash #-}
{-# OPTIONS_HADDOCK hide #-}
-----------------------------------------------------------------------------
-- |
-- Module      :  GHC.Int
-- Copyright   :  (c) The University of Glasgow 1997-2002
-- License     :  see libraries/base/LICENSE
-- 
-- Maintainer  :  cvs-ghc@haskell.org
-- Stability   :  internal
-- Portability :  non-portable (GHC Extensions)
--
-- The sized integral datatypes, 'Int8', 'Int16', 'Int32', and 'Int64'.
--
-----------------------------------------------------------------------------

#include "MachDeps.h"

-- #hide
module GHC.Int (
    Int8(..), Int16(..), Int32(..), Int64(..),
    uncheckedIShiftL64#, uncheckedIShiftRA64#
    ) where

import Data.Bits

#if WORD_SIZE_IN_BITS < 32
import GHC.IntWord32
#endif
#if WORD_SIZE_IN_BITS < 64
import GHC.IntWord64
#endif

import GHC.Base
import GHC.Enum
import GHC.Num
import GHC.Real
import GHC.Read
import GHC.Arr
import GHC.Err
import GHC.Word hiding (uncheckedShiftL64#, uncheckedShiftRL64#)
import GHC.Show
import GHC.Float ()     -- for RealFrac methods

------------------------------------------------------------------------
-- type Int8
------------------------------------------------------------------------

-- Int8 is represented in the same way as Int. Operations may assume
-- and must ensure that it holds only values from its logical range.

data Int8 = I8# Int# deriving (Eq, Ord)
-- ^ 8-bit signed integer type

instance Show Int8 where
    showsPrec p x = showsPrec p (fromIntegral x :: Int)

instance Num Int8 where
    (I8# x#) + (I8# y#)    = I8# (narrow8Int# (x# +# y#))
    (I8# x#) - (I8# y#)    = I8# (narrow8Int# (x# -# y#))
    (I8# x#) * (I8# y#)    = I8# (narrow8Int# (x# *# y#))
    negate (I8# x#)        = I8# (narrow8Int# (negateInt# x#))
    abs x | x >= 0         = x
          | otherwise      = negate x
    signum x | x > 0       = 1
    signum 0               = 0
    signum _               = -1
    fromInteger i          = I8# (narrow8Int# (toInt# i))

instance Real Int8 where
    toRational x = toInteger x % 1

instance Enum Int8 where
    succ x
        | x /= maxBound = x + 1
        | otherwise     = succError "Int8"
    pred x
        | x /= minBound = x - 1
        | otherwise     = predError "Int8"
    toEnum i@(I# i#)
        | i >= fromIntegral (minBound::Int8) && i <= fromIntegral (maxBound::Int8)
                        = I8# i#
        | otherwise     = toEnumError "Int8" i (minBound::Int8, maxBound::Int8)
    fromEnum (I8# x#)   = I# x#
    enumFrom            = boundedEnumFrom
    enumFromThen        = boundedEnumFromThen

instance Integral Int8 where
    quot    x@(I8# x#) y@(I8# y#)
        | y == 0                     = divZeroError
        | x == minBound && y == (-1) = overflowError
        | otherwise                  = I8# (narrow8Int# (x# `quotInt#` y#))
    rem     x@(I8# x#) y@(I8# y#)
        | y == 0                     = divZeroError
        | x == minBound && y == (-1) = overflowError
        | otherwise                  = I8# (narrow8Int# (x# `remInt#` y#))
    div     x@(I8# x#) y@(I8# y#)
        | y == 0                     = divZeroError
        | x == minBound && y == (-1) = overflowError
        | otherwise                  = I8# (narrow8Int# (x# `divInt#` y#))
    mod     x@(I8# x#) y@(I8# y#)
        | y == 0                     = divZeroError
        | x == minBound && y == (-1) = overflowError
        | otherwise                  = I8# (narrow8Int# (x# `modInt#` y#))
    quotRem x@(I8# x#) y@(I8# y#)
        | y == 0                     = divZeroError
        | x == minBound && y == (-1) = overflowError
        | otherwise                  = (I8# (narrow8Int# (x# `quotInt#` y#)),
                                       I8# (narrow8Int# (x# `remInt#` y#)))
    divMod  x@(I8# x#) y@(I8# y#)
        | y == 0                     = divZeroError
        | x == minBound && y == (-1) = overflowError
        | otherwise                  = (I8# (narrow8Int# (x# `divInt#` y#)),
                                       I8# (narrow8Int# (x# `modInt#` y#)))
    toInteger (I8# x#)               = smallInteger x#

instance Bounded Int8 where
    minBound = -0x80
    maxBound =  0x7F

instance Ix Int8 where
    range (m,n)         = [m..n]
    unsafeIndex (m,_) i = fromIntegral i - fromIntegral m
    inRange (m,n) i     = m <= i && i <= n

instance Read Int8 where
    readsPrec p s = [(fromIntegral (x::Int), r) | (x, r) <- readsPrec p s]

instance Bits Int8 where
    {-# INLINE shift #-}

    (I8# x#) .&.   (I8# y#)   = I8# (word2Int# (int2Word# x# `and#` int2Word# y#))
    (I8# x#) .|.   (I8# y#)   = I8# (word2Int# (int2Word# x# `or#`  int2Word# y#))
    (I8# x#) `xor` (I8# y#)   = I8# (word2Int# (int2Word# x# `xor#` int2Word# y#))
    complement (I8# x#)       = I8# (word2Int# (int2Word# x# `xor#` int2Word# (-1#)))
    (I8# x#) `shift` (I# i#)
        | i# >=# 0#           = I8# (narrow8Int# (x# `iShiftL#` i#))
        | otherwise           = I8# (x# `iShiftRA#` negateInt# i#)
    (I8# x#) `rotate` (I# i#)
        | i'# ==# 0# 
        = I8# x#
        | otherwise
        = I8# (narrow8Int# (word2Int# ((x'# `uncheckedShiftL#` i'#) `or#`
                                       (x'# `uncheckedShiftRL#` (8# -# i'#)))))
        where
        !x'# = narrow8Word# (int2Word# x#)
        !i'# = word2Int# (int2Word# i# `and#` int2Word# 7#)
    bitSize  _                = 8
    isSigned _                = True

{-# RULES
"fromIntegral/Int8->Int8" fromIntegral = id :: Int8 -> Int8
"fromIntegral/a->Int8"    fromIntegral = \x -> case fromIntegral x of I# x# -> I8# (narrow8Int# x#)
"fromIntegral/Int8->a"    fromIntegral = \(I8# x#) -> fromIntegral (I# x#)
  #-}

{-# RULES
"properFraction/Float->(Int8,Float)"
    forall x. properFraction (x :: Float) =
                      case properFraction x of {
                        (n, y) -> ((fromIntegral :: Int -> Int8) n, y) }
"truncate/Float->Int8"
    forall x. truncate (x :: Float) = (fromIntegral :: Int -> Int8) (truncate x)
"floor/Float->Int8"
    forall x. floor    (x :: Float) = (fromIntegral :: Int -> Int8) (floor x)
"ceiling/Float->Int8"
    forall x. ceiling  (x :: Float) = (fromIntegral :: Int -> Int8) (ceiling x)
"round/Float->Int8"
    forall x. round    (x :: Float) = (fromIntegral :: Int -> Int8) (round x)
  #-}

{-# RULES
"properFraction/Double->(Int8,Double)"
    forall x. properFraction (x :: Double) =
                      case properFraction x of {
                        (n, y) -> ((fromIntegral :: Int -> Int8) n, y) }
"truncate/Double->Int8"
    forall x. truncate (x :: Double) = (fromIntegral :: Int -> Int8) (truncate x)
"floor/Double->Int8"
    forall x. floor    (x :: Double) = (fromIntegral :: Int -> Int8) (floor x)
"ceiling/Double->Int8"
    forall x. ceiling  (x :: Double) = (fromIntegral :: Int -> Int8) (ceiling x)
"round/Double->Int8"
    forall x. round    (x :: Double) = (fromIntegral :: Int -> Int8) (round x)
  #-}

------------------------------------------------------------------------
-- type Int16
------------------------------------------------------------------------

-- Int16 is represented in the same way as Int. Operations may assume
-- and must ensure that it holds only values from its logical range.

data Int16 = I16# Int# deriving (Eq, Ord)
-- ^ 16-bit signed integer type

instance Show Int16 where
    showsPrec p x = showsPrec p (fromIntegral x :: Int)

instance Num Int16 where
    (I16# x#) + (I16# y#)  = I16# (narrow16Int# (x# +# y#))
    (I16# x#) - (I16# y#)  = I16# (narrow16Int# (x# -# y#))
    (I16# x#) * (I16# y#)  = I16# (narrow16Int# (x# *# y#))
    negate (I16# x#)       = I16# (narrow16Int# (negateInt# x#))
    abs x | x >= 0         = x
          | otherwise      = negate x
    signum x | x > 0       = 1
    signum 0               = 0
    signum _               = -1
    fromInteger i          = I16# (narrow16Int# (toInt# i))

instance Real Int16 where
    toRational x = toInteger x % 1

instance Enum Int16 where
    succ x
        | x /= maxBound = x + 1
        | otherwise     = succError "Int16"
    pred x
        | x /= minBound = x - 1
        | otherwise     = predError "Int16"
    toEnum i@(I# i#)
        | i >= fromIntegral (minBound::Int16) && i <= fromIntegral (maxBound::Int16)
                        = I16# i#
        | otherwise     = toEnumError "Int16" i (minBound::Int16, maxBound::Int16)
    fromEnum (I16# x#)  = I# x#
    enumFrom            = boundedEnumFrom
    enumFromThen        = boundedEnumFromThen

instance Integral Int16 where
    quot    x@(I16# x#) y@(I16# y#)
        | y == 0                     = divZeroError
        | x == minBound && y == (-1) = overflowError
        | otherwise                  = I16# (narrow16Int# (x# `quotInt#` y#))
    rem     x@(I16# x#) y@(I16# y#)
        | y == 0                     = divZeroError
        | x == minBound && y == (-1) = overflowError
        | otherwise                  = I16# (narrow16Int# (x# `remInt#` y#))
    div     x@(I16# x#) y@(I16# y#)
        | y == 0                     = divZeroError
        | x == minBound && y == (-1) = overflowError
        | otherwise                  = I16# (narrow16Int# (x# `divInt#` y#))
    mod     x@(I16# x#) y@(I16# y#)
        | y == 0                     = divZeroError
        | x == minBound && y == (-1) = overflowError
        | otherwise                  = I16# (narrow16Int# (x# `modInt#` y#))
    quotRem x@(I16# x#) y@(I16# y#)
        | y == 0                     = divZeroError
        | x == minBound && y == (-1) = overflowError
        | otherwise                  = (I16# (narrow16Int# (x# `quotInt#` y#)),
                                        I16# (narrow16Int# (x# `remInt#` y#)))
    divMod  x@(I16# x#) y@(I16# y#)
        | y == 0                     = divZeroError
        | x == minBound && y == (-1) = overflowError
        | otherwise                  = (I16# (narrow16Int# (x# `divInt#` y#)),
                                        I16# (narrow16Int# (x# `modInt#` y#)))
    toInteger (I16# x#)              = smallInteger x#

instance Bounded Int16 where
    minBound = -0x8000
    maxBound =  0x7FFF

instance Ix Int16 where
    range (m,n)         = [m..n]
    unsafeIndex (m,_) i = fromIntegral i - fromIntegral m
    inRange (m,n) i     = m <= i && i <= n

instance Read Int16 where
    readsPrec p s = [(fromIntegral (x::Int), r) | (x, r) <- readsPrec p s]

instance Bits Int16 where
    {-# INLINE shift #-}

    (I16# x#) .&.   (I16# y#)  = I16# (word2Int# (int2Word# x# `and#` int2Word# y#))
    (I16# x#) .|.   (I16# y#)  = I16# (word2Int# (int2Word# x# `or#`  int2Word# y#))
    (I16# x#) `xor` (I16# y#)  = I16# (word2Int# (int2Word# x# `xor#` int2Word# y#))
    complement (I16# x#)       = I16# (word2Int# (int2Word# x# `xor#` int2Word# (-1#)))
    (I16# x#) `shift` (I# i#)
        | i# >=# 0#            = I16# (narrow16Int# (x# `iShiftL#` i#))
        | otherwise            = I16# (x# `iShiftRA#` negateInt# i#)
    (I16# x#) `rotate` (I# i#)
        | i'# ==# 0# 
        = I16# x#
        | otherwise
        = I16# (narrow16Int# (word2Int# ((x'# `uncheckedShiftL#` i'#) `or#`
                                         (x'# `uncheckedShiftRL#` (16# -# i'#)))))
        where
        !x'# = narrow16Word# (int2Word# x#)
        !i'# = word2Int# (int2Word# i# `and#` int2Word# 15#)
    bitSize  _                 = 16
    isSigned _                 = True


{-# RULES
"fromIntegral/Word8->Int16"  fromIntegral = \(W8# x#) -> I16# (word2Int# x#)
"fromIntegral/Int8->Int16"   fromIntegral = \(I8# x#) -> I16# x#
"fromIntegral/Int16->Int16"  fromIntegral = id :: Int16 -> Int16
"fromIntegral/a->Int16"      fromIntegral = \x -> case fromIntegral x of I# x# -> I16# (narrow16Int# x#)
"fromIntegral/Int16->a"      fromIntegral = \(I16# x#) -> fromIntegral (I# x#)
  #-}

{-# RULES
"properFraction/Float->(Int16,Float)"
    forall x. properFraction (x :: Float) =
                      case properFraction x of {
                        (n, y) -> ((fromIntegral :: Int -> Int16) n, y) }
"truncate/Float->Int16"
    forall x. truncate (x :: Float) = (fromIntegral :: Int -> Int16) (truncate x)
"floor/Float->Int16"
    forall x. floor    (x :: Float) = (fromIntegral :: Int -> Int16) (floor x)
"ceiling/Float->Int16"
    forall x. ceiling  (x :: Float) = (fromIntegral :: Int -> Int16) (ceiling x)
"round/Float->Int16"
    forall x. round    (x :: Float) = (fromIntegral :: Int -> Int16) (round x)
  #-}

{-# RULES
"properFraction/Double->(Int16,Double)"
    forall x. properFraction (x :: Double) =
                      case properFraction x of {
                        (n, y) -> ((fromIntegral :: Int -> Int16) n, y) }
"truncate/Double->Int16"
    forall x. truncate (x :: Double) = (fromIntegral :: Int -> Int16) (truncate x)
"floor/Double->Int16"
    forall x. floor    (x :: Double) = (fromIntegral :: Int -> Int16) (floor x)
"ceiling/Double->Int16"
    forall x. ceiling  (x :: Double) = (fromIntegral :: Int -> Int16) (ceiling x)
"round/Double->Int16"
    forall x. round    (x :: Double) = (fromIntegral :: Int -> Int16) (round x)
  #-}

------------------------------------------------------------------------
-- type Int32
------------------------------------------------------------------------

#if WORD_SIZE_IN_BITS < 32

data Int32 = I32# Int32#
-- ^ 32-bit signed integer type

instance Eq Int32 where
    (I32# x#) == (I32# y#) = x# `eqInt32#` y#
    (I32# x#) /= (I32# y#) = x# `neInt32#` y#

instance Ord Int32 where
    (I32# x#) <  (I32# y#) = x# `ltInt32#` y#
    (I32# x#) <= (I32# y#) = x# `leInt32#` y#
    (I32# x#) >  (I32# y#) = x# `gtInt32#` y#
    (I32# x#) >= (I32# y#) = x# `geInt32#` y#

instance Show Int32 where
    showsPrec p x = showsPrec p (toInteger x)

instance Num Int32 where
    (I32# x#) + (I32# y#)  = I32# (x# `plusInt32#`  y#)
    (I32# x#) - (I32# y#)  = I32# (x# `minusInt32#` y#)
    (I32# x#) * (I32# y#)  = I32# (x# `timesInt32#` y#)
    negate (I32# x#)       = I32# (negateInt32# x#)
    abs x | x >= 0         = x
          | otherwise      = negate x
    signum x | x > 0       = 1
    signum 0               = 0
    signum _               = -1
    fromInteger (S# i#)    = I32# (intToInt32# i#)
    fromInteger (J# s# d#) = I32# (integerToInt32# s# d#)

instance Enum Int32 where
    succ x
        | x /= maxBound = x + 1
        | otherwise     = succError "Int32"
    pred x
        | x /= minBound = x - 1
        | otherwise     = predError "Int32"
    toEnum (I# i#)      = I32# (intToInt32# i#)
    fromEnum x@(I32# x#)
        | x >= fromIntegral (minBound::Int) && x <= fromIntegral (maxBound::Int)
                        = I# (int32ToInt# x#)
        | otherwise     = fromEnumError "Int32" x
    enumFrom            = integralEnumFrom
    enumFromThen        = integralEnumFromThen
    enumFromTo          = integralEnumFromTo
    enumFromThenTo      = integralEnumFromThenTo

instance Integral Int32 where
    quot    x@(I32# x#) y@(I32# y#)
        | y == 0                     = divZeroError
        | x == minBound && y == (-1) = overflowError
        | otherwise                  = I32# (x# `quotInt32#` y#)
    rem     x@(I32# x#) y@(I32# y#)
        | y == 0                  = divZeroError
        | x == minBound && y == (-1) = overflowError
        | otherwise               = I32# (x# `remInt32#` y#)
    div     x@(I32# x#) y@(I32# y#)
        | y == 0                  = divZeroError
        | x == minBound && y == (-1) = overflowError
        | otherwise               = I32# (x# `divInt32#` y#)
    mod     x@(I32# x#) y@(I32# y#)
        | y == 0                  = divZeroError
        | x == minBound && y == (-1) = overflowError
        | otherwise               = I32# (x# `modInt32#` y#)
    quotRem x@(I32# x#) y@(I32# y#)
        | y == 0                  = divZeroError
        | x == minBound && y == (-1) = overflowError
        | otherwise               = (I32# (x# `quotInt32#` y#),
                                     I32# (x# `remInt32#` y#))
    divMod  x@(I32# x#) y@(I32# y#)
        | y == 0                  = divZeroError
        | x == minBound && y == (-1) = overflowError
        | otherwise               = (I32# (x# `divInt32#` y#),
                                     I32# (x# `modInt32#` y#))
    toInteger x@(I32# x#)
	| x >= fromIntegral (minBound::Int) && x <= fromIntegral (maxBound::Int)
                                  = smallInteger (int32ToInt# x#)
        | otherwise               = case int32ToInteger# x# of (# s, d #) -> J# s d

divInt32#, modInt32# :: Int32# -> Int32# -> Int32#
x# `divInt32#` y#
    | (x# `gtInt32#` intToInt32# 0#) && (y# `ltInt32#` intToInt32# 0#)
        = ((x# `minusInt32#` y#) `minusInt32#` intToInt32# 1#) `quotInt32#` y#
    | (x# `ltInt32#` intToInt32# 0#) && (y# `gtInt32#` intToInt32# 0#)
        = ((x# `minusInt32#` y#) `plusInt32#` intToInt32# 1#) `quotInt32#` y#
    | otherwise                = x# `quotInt32#` y#
x# `modInt32#` y#
    | (x# `gtInt32#` intToInt32# 0#) && (y# `ltInt32#` intToInt32# 0#) ||
      (x# `ltInt32#` intToInt32# 0#) && (y# `gtInt32#` intToInt32# 0#)
        = if r# `neInt32#` intToInt32# 0# then r# `plusInt32#` y# else intToInt32# 0#
    | otherwise = r#
    where
    r# = x# `remInt32#` y#

instance Read Int32 where
    readsPrec p s = [(fromInteger x, r) | (x, r) <- readsPrec p s]

instance Bits Int32 where
    {-# INLINE shift #-}

    (I32# x#) .&.   (I32# y#)  = I32# (word32ToInt32# (int32ToWord32# x# `and32#` int32ToWord32# y#))
    (I32# x#) .|.   (I32# y#)  = I32# (word32ToInt32# (int32ToWord32# x# `or32#`  int32ToWord32# y#))
    (I32# x#) `xor` (I32# y#)  = I32# (word32ToInt32# (int32ToWord32# x# `xor32#` int32ToWord32# y#))
    complement (I32# x#)       = I32# (word32ToInt32# (not32# (int32ToWord32# x#)))
    (I32# x#) `shift` (I# i#)
        | i# >=# 0#            = I32# (x# `iShiftL32#` i#)
        | otherwise            = I32# (x# `iShiftRA32#` negateInt# i#)
    (I32# x#) `rotate` (I# i#)
        | i'# ==# 0# 
        = I32# x#
        | otherwise
        = I32# (word32ToInt32# ((x'# `shiftL32#` i'#) `or32#`
                                (x'# `shiftRL32#` (32# -# i'#))))
        where
        x'# = int32ToWord32# x#
        i'# = word2Int# (int2Word# i# `and#` int2Word# 31#)
    bitSize  _                 = 32
    isSigned _                 = True


{-# RULES
"fromIntegral/Int->Int32"    fromIntegral = \(I#   x#) -> I32# (intToInt32# x#)
"fromIntegral/Word->Int32"   fromIntegral = \(W#   x#) -> I32# (word32ToInt32# (wordToWord32# x#))
"fromIntegral/Word32->Int32" fromIntegral = \(W32# x#) -> I32# (word32ToInt32# x#)
"fromIntegral/Int32->Int"    fromIntegral = \(I32# x#) -> I#   (int32ToInt# x#)
"fromIntegral/Int32->Word"   fromIntegral = \(I32# x#) -> W#   (int2Word# (int32ToInt# x#))
"fromIntegral/Int32->Word32" fromIntegral = \(I32# x#) -> W32# (int32ToWord32# x#)
"fromIntegral/Int32->Int32"  fromIntegral = id :: Int32 -> Int32
  #-}

-- No rules for RealFrac methods if Int32 is larger than Int
#else

-- Int32 is represented in the same way as Int.
#if WORD_SIZE_IN_BITS > 32
-- Operations may assume and must ensure that it holds only values
-- from its logical range.
#endif

data Int32 = I32# Int# deriving (Eq, Ord)
-- ^ 32-bit signed integer type

instance Show Int32 where
    showsPrec p x = showsPrec p (fromIntegral x :: Int)

instance Num Int32 where
    (I32# x#) + (I32# y#)  = I32# (narrow32Int# (x# +# y#))
    (I32# x#) - (I32# y#)  = I32# (narrow32Int# (x# -# y#))
    (I32# x#) * (I32# y#)  = I32# (narrow32Int# (x# *# y#))
    negate (I32# x#)       = I32# (narrow32Int# (negateInt# x#))
    abs x | x >= 0         = x
          | otherwise      = negate x
    signum x | x > 0       = 1
    signum 0               = 0
    signum _               = -1
    fromInteger i          = I32# (narrow32Int# (toInt# i))

instance Enum Int32 where
    succ x
        | x /= maxBound = x + 1
        | otherwise     = succError "Int32"
    pred x
        | x /= minBound = x - 1
        | otherwise     = predError "Int32"
#if WORD_SIZE_IN_BITS == 32
    toEnum (I# i#)      = I32# i#
#else
    toEnum i@(I# i#)
        | i >= fromIntegral (minBound::Int32) && i <= fromIntegral (maxBound::Int32)
                        = I32# i#
        | otherwise     = toEnumError "Int32" i (minBound::Int32, maxBound::Int32)
#endif
    fromEnum (I32# x#)  = I# x#
    enumFrom            = boundedEnumFrom
    enumFromThen        = boundedEnumFromThen

instance Integral Int32 where
    quot    x@(I32# x#) y@(I32# y#)
        | y == 0                     = divZeroError
        | x == minBound && y == (-1) = overflowError
        | otherwise                  = I32# (narrow32Int# (x# `quotInt#` y#))
    rem     x@(I32# x#) y@(I32# y#)
        | y == 0                     = divZeroError
        | x == minBound && y == (-1) = overflowError
        | otherwise                  = I32# (narrow32Int# (x# `remInt#` y#))
    div     x@(I32# x#) y@(I32# y#)
        | y == 0                     = divZeroError
        | x == minBound && y == (-1) = overflowError
        | otherwise                  = I32# (narrow32Int# (x# `divInt#` y#))
    mod     x@(I32# x#) y@(I32# y#)
        | y == 0                     = divZeroError
        | x == minBound && y == (-1) = overflowError
        | otherwise                  = I32# (narrow32Int# (x# `modInt#` y#))
    quotRem x@(I32# x#) y@(I32# y#)
        | y == 0                     = divZeroError
        | x == minBound && y == (-1) = overflowError
        | otherwise                  = (I32# (narrow32Int# (x# `quotInt#` y#)),
                                     I32# (narrow32Int# (x# `remInt#` y#)))
    divMod  x@(I32# x#) y@(I32# y#)
        | y == 0                     = divZeroError
        | x == minBound && y == (-1) = overflowError
        | otherwise                  = (I32# (narrow32Int# (x# `divInt#` y#)),
                                     I32# (narrow32Int# (x# `modInt#` y#)))
    toInteger (I32# x#)              = smallInteger x#

instance Read Int32 where
    readsPrec p s = [(fromIntegral (x::Int), r) | (x, r) <- readsPrec p s]

instance Bits Int32 where
    {-# INLINE shift #-}

    (I32# x#) .&.   (I32# y#)  = I32# (word2Int# (int2Word# x# `and#` int2Word# y#))
    (I32# x#) .|.   (I32# y#)  = I32# (word2Int# (int2Word# x# `or#`  int2Word# y#))
    (I32# x#) `xor` (I32# y#)  = I32# (word2Int# (int2Word# x# `xor#` int2Word# y#))
    complement (I32# x#)       = I32# (word2Int# (int2Word# x# `xor#` int2Word# (-1#)))
    (I32# x#) `shift` (I# i#)
        | i# >=# 0#            = I32# (narrow32Int# (x# `iShiftL#` i#))
        | otherwise            = I32# (x# `iShiftRA#` negateInt# i#)
    (I32# x#) `rotate` (I# i#)
        | i'# ==# 0# 
        = I32# x#
        | otherwise
        = I32# (narrow32Int# (word2Int# ((x'# `uncheckedShiftL#` i'#) `or#`
                                         (x'# `uncheckedShiftRL#` (32# -# i'#)))))
        where
        !x'# = narrow32Word# (int2Word# x#)
        !i'# = word2Int# (int2Word# i# `and#` int2Word# 31#)
    bitSize  _                 = 32
    isSigned _                 = True

{-# RULES
"fromIntegral/Word8->Int32"  fromIntegral = \(W8# x#) -> I32# (word2Int# x#)
"fromIntegral/Word16->Int32" fromIntegral = \(W16# x#) -> I32# (word2Int# x#)
"fromIntegral/Int8->Int32"   fromIntegral = \(I8# x#) -> I32# x#
"fromIntegral/Int16->Int32"  fromIntegral = \(I16# x#) -> I32# x#
"fromIntegral/Int32->Int32"  fromIntegral = id :: Int32 -> Int32
"fromIntegral/a->Int32"      fromIntegral = \x -> case fromIntegral x of I# x# -> I32# (narrow32Int# x#)
"fromIntegral/Int32->a"      fromIntegral = \(I32# x#) -> fromIntegral (I# x#)
  #-}

{-# RULES
"properFraction/Float->(Int32,Float)"
    forall x. properFraction (x :: Float) =
                      case properFraction x of {
                        (n, y) -> ((fromIntegral :: Int -> Int32) n, y) }
"truncate/Float->Int32"
    forall x. truncate (x :: Float) = (fromIntegral :: Int -> Int32) (truncate x)
"floor/Float->Int32"
    forall x. floor    (x :: Float) = (fromIntegral :: Int -> Int32) (floor x)
"ceiling/Float->Int32"
    forall x. ceiling  (x :: Float) = (fromIntegral :: Int -> Int32) (ceiling x)
"round/Float->Int32"
    forall x. round    (x :: Float) = (fromIntegral :: Int -> Int32) (round x)
  #-}

{-# RULES
"properFraction/Double->(Int32,Double)"
    forall x. properFraction (x :: Double) =
                      case properFraction x of {
                        (n, y) -> ((fromIntegral :: Int -> Int32) n, y) }
"truncate/Double->Int32"
    forall x. truncate (x :: Double) = (fromIntegral :: Int -> Int32) (truncate x)
"floor/Double->Int32"
    forall x. floor    (x :: Double) = (fromIntegral :: Int -> Int32) (floor x)
"ceiling/Double->Int32"
    forall x. ceiling  (x :: Double) = (fromIntegral :: Int -> Int32) (ceiling x)
"round/Double->Int32"
    forall x. round    (x :: Double) = (fromIntegral :: Int -> Int32) (round x)
  #-}

#endif

instance Real Int32 where
    toRational x = toInteger x % 1

instance Bounded Int32 where
    minBound = -0x80000000
    maxBound =  0x7FFFFFFF

instance Ix Int32 where
    range (m,n)         = [m..n]
    unsafeIndex (m,_) i = fromIntegral i - fromIntegral m
    inRange (m,n) i     = m <= i && i <= n

------------------------------------------------------------------------
-- type Int64
------------------------------------------------------------------------

#if WORD_SIZE_IN_BITS < 64

data Int64 = I64# Int64#
-- ^ 64-bit signed integer type

instance Eq Int64 where
    (I64# x#) == (I64# y#) = x# `eqInt64#` y#
    (I64# x#) /= (I64# y#) = x# `neInt64#` y#

instance Ord Int64 where
    (I64# x#) <  (I64# y#) = x# `ltInt64#` y#
    (I64# x#) <= (I64# y#) = x# `leInt64#` y#
    (I64# x#) >  (I64# y#) = x# `gtInt64#` y#
    (I64# x#) >= (I64# y#) = x# `geInt64#` y#

instance Show Int64 where
    showsPrec p x = showsPrec p (toInteger x)

instance Num Int64 where
    (I64# x#) + (I64# y#)  = I64# (x# `plusInt64#`  y#)
    (I64# x#) - (I64# y#)  = I64# (x# `minusInt64#` y#)
    (I64# x#) * (I64# y#)  = I64# (x# `timesInt64#` y#)
    negate (I64# x#)       = I64# (negateInt64# x#)
    abs x | x >= 0         = x
          | otherwise      = negate x
    signum x | x > 0       = 1
    signum 0               = 0
    signum _               = -1
    fromInteger i          = I64# (integerToInt64 i)

instance Enum Int64 where
    succ x
        | x /= maxBound = x + 1
        | otherwise     = succError "Int64"
    pred x
        | x /= minBound = x - 1
        | otherwise     = predError "Int64"
    toEnum (I# i#)      = I64# (intToInt64# i#)
    fromEnum x@(I64# x#)
        | x >= fromIntegral (minBound::Int) && x <= fromIntegral (maxBound::Int)
                        = I# (int64ToInt# x#)
        | otherwise     = fromEnumError "Int64" x
    enumFrom            = integralEnumFrom
    enumFromThen        = integralEnumFromThen
    enumFromTo          = integralEnumFromTo
    enumFromThenTo      = integralEnumFromThenTo

instance Integral Int64 where
    quot    x@(I64# x#) y@(I64# y#)
        | y == 0                     = divZeroError
        | x == minBound && y == (-1) = overflowError
        | otherwise                  = I64# (x# `quotInt64#` y#)
    rem     x@(I64# x#) y@(I64# y#)
        | y == 0                     = divZeroError
        | x == minBound && y == (-1) = overflowError
        | otherwise                  = I64# (x# `remInt64#` y#)
    div     x@(I64# x#) y@(I64# y#)
        | y == 0                     = divZeroError
        | x == minBound && y == (-1) = overflowError
        | otherwise                  = I64# (x# `divInt64#` y#)
    mod     x@(I64# x#) y@(I64# y#)
        | y == 0                     = divZeroError
        | x == minBound && y == (-1) = overflowError
        | otherwise                  = I64# (x# `modInt64#` y#)
    quotRem x@(I64# x#) y@(I64# y#)
        | y == 0                     = divZeroError
        | x == minBound && y == (-1) = overflowError
        | otherwise                  = (I64# (x# `quotInt64#` y#),
                                        I64# (x# `remInt64#` y#))
    divMod  x@(I64# x#) y@(I64# y#)
        | y == 0                     = divZeroError
        | x == minBound && y == (-1) = overflowError
        | otherwise                  = (I64# (x# `divInt64#` y#),
                                        I64# (x# `modInt64#` y#))
    toInteger (I64# x)               = int64ToInteger x


divInt64#, modInt64# :: Int64# -> Int64# -> Int64#
x# `divInt64#` y#
    | (x# `gtInt64#` intToInt64# 0#) && (y# `ltInt64#` intToInt64# 0#)
        = ((x# `minusInt64#` y#) `minusInt64#` intToInt64# 1#) `quotInt64#` y#
    | (x# `ltInt64#` intToInt64# 0#) && (y# `gtInt64#` intToInt64# 0#)
        = ((x# `minusInt64#` y#) `plusInt64#` intToInt64# 1#) `quotInt64#` y#
    | otherwise                = x# `quotInt64#` y#
x# `modInt64#` y#
    | (x# `gtInt64#` intToInt64# 0#) && (y# `ltInt64#` intToInt64# 0#) ||
      (x# `ltInt64#` intToInt64# 0#) && (y# `gtInt64#` intToInt64# 0#)
        = if r# `neInt64#` intToInt64# 0# then r# `plusInt64#` y# else intToInt64# 0#
    | otherwise = r#
    where
    !r# = x# `remInt64#` y#

instance Read Int64 where
    readsPrec p s = [(fromInteger x, r) | (x, r) <- readsPrec p s]

instance Bits Int64 where
    {-# INLINE shift #-}

    (I64# x#) .&.   (I64# y#)  = I64# (word64ToInt64# (int64ToWord64# x# `and64#` int64ToWord64# y#))
    (I64# x#) .|.   (I64# y#)  = I64# (word64ToInt64# (int64ToWord64# x# `or64#`  int64ToWord64# y#))
    (I64# x#) `xor` (I64# y#)  = I64# (word64ToInt64# (int64ToWord64# x# `xor64#` int64ToWord64# y#))
    complement (I64# x#)       = I64# (word64ToInt64# (not64# (int64ToWord64# x#)))
    (I64# x#) `shift` (I# i#)
        | i# >=# 0#            = I64# (x# `iShiftL64#` i#)
        | otherwise            = I64# (x# `iShiftRA64#` negateInt# i#)
    (I64# x#) `rotate` (I# i#)
        | i'# ==# 0# 
        = I64# x#
        | otherwise
        = I64# (word64ToInt64# ((x'# `uncheckedShiftL64#` i'#) `or64#`
                                (x'# `uncheckedShiftRL64#` (64# -# i'#))))
        where
        !x'# = int64ToWord64# x#
        !i'# = word2Int# (int2Word# i# `and#` int2Word# 63#)
    bitSize  _                 = 64
    isSigned _                 = True

-- give the 64-bit shift operations the same treatment as the 32-bit
-- ones (see GHC.Base), namely we wrap them in tests to catch the
-- cases when we're shifting more than 64 bits to avoid unspecified
-- behaviour in the C shift operations.

iShiftL64#, iShiftRA64# :: Int64# -> Int# -> Int64#

a `iShiftL64#` b  | b >=# 64# = intToInt64# 0#
		  | otherwise = a `uncheckedIShiftL64#` b

a `iShiftRA64#` b | b >=# 64# = if a `ltInt64#` (intToInt64# 0#) 
					then intToInt64# (-1#) 
					else intToInt64# 0#
		  | otherwise = a `uncheckedIShiftRA64#` b

{-# RULES
"fromIntegral/Int->Int64"    fromIntegral = \(I#   x#) -> I64# (intToInt64# x#)
"fromIntegral/Word->Int64"   fromIntegral = \(W#   x#) -> I64# (word64ToInt64# (wordToWord64# x#))
"fromIntegral/Word64->Int64" fromIntegral = \(W64# x#) -> I64# (word64ToInt64# x#)
"fromIntegral/Int64->Int"    fromIntegral = \(I64# x#) -> I#   (int64ToInt# x#)
"fromIntegral/Int64->Word"   fromIntegral = \(I64# x#) -> W#   (int2Word# (int64ToInt# x#))
"fromIntegral/Int64->Word64" fromIntegral = \(I64# x#) -> W64# (int64ToWord64# x#)
"fromIntegral/Int64->Int64"  fromIntegral = id :: Int64 -> Int64
  #-}

-- No RULES for RealFrac methods if Int is smaller than Int64, we can't
-- go through Int and whether going through Integer is faster is uncertain.
#else

-- Int64 is represented in the same way as Int.
-- Operations may assume and must ensure that it holds only values
-- from its logical range.

data Int64 = I64# Int# deriving (Eq, Ord)
-- ^ 64-bit signed integer type

instance Show Int64 where
    showsPrec p x = showsPrec p (fromIntegral x :: Int)

instance Num Int64 where
    (I64# x#) + (I64# y#)  = I64# (x# +# y#)
    (I64# x#) - (I64# y#)  = I64# (x# -# y#)
    (I64# x#) * (I64# y#)  = I64# (x# *# y#)
    negate (I64# x#)       = I64# (negateInt# x#)
    abs x | x >= 0         = x
          | otherwise      = negate x
    signum x | x > 0       = 1
    signum 0               = 0
    signum _               = -1
    fromInteger i          = I64# (toInt# i)

instance Enum Int64 where
    succ x
        | x /= maxBound = x + 1
        | otherwise     = succError "Int64"
    pred x
        | x /= minBound = x - 1
        | otherwise     = predError "Int64"
    toEnum (I# i#)      = I64# i#
    fromEnum (I64# x#)  = I# x#
    enumFrom            = boundedEnumFrom
    enumFromThen        = boundedEnumFromThen

instance Integral Int64 where
    quot    x@(I64# x#) y@(I64# y#)
        | y == 0                     = divZeroError
        | x == minBound && y == (-1) = overflowError
        | otherwise                  = I64# (x# `quotInt#` y#)
    rem     x@(I64# x#) y@(I64# y#)
        | y == 0                     = divZeroError
        | x == minBound && y == (-1) = overflowError
        | otherwise                  = I64# (x# `remInt#` y#)
    div     x@(I64# x#) y@(I64# y#)
        | y == 0                     = divZeroError
        | x == minBound && y == (-1) = overflowError
        | otherwise                  = I64# (x# `divInt#` y#)
    mod     x@(I64# x#) y@(I64# y#)
        | y == 0                     = divZeroError
        | x == minBound && y == (-1) = overflowError
        | otherwise                  = I64# (x# `modInt#` y#)
    quotRem x@(I64# x#) y@(I64# y#)
        | y == 0                     = divZeroError
        | x == minBound && y == (-1) = overflowError
        | otherwise                  = (I64# (x# `quotInt#` y#), I64# (x# `remInt#` y#))
    divMod  x@(I64# x#) y@(I64# y#)
        | y == 0                     = divZeroError
        | x == minBound && y == (-1) = overflowError
        | otherwise                  = (I64# (x# `divInt#` y#), I64# (x# `modInt#` y#))
    toInteger (I64# x#)              = smallInteger x#

instance Read Int64 where
    readsPrec p s = [(fromIntegral (x::Int), r) | (x, r) <- readsPrec p s]

instance Bits Int64 where
    {-# INLINE shift #-}

    (I64# x#) .&.   (I64# y#)  = I64# (word2Int# (int2Word# x# `and#` int2Word# y#))
    (I64# x#) .|.   (I64# y#)  = I64# (word2Int# (int2Word# x# `or#`  int2Word# y#))
    (I64# x#) `xor` (I64# y#)  = I64# (word2Int# (int2Word# x# `xor#` int2Word# y#))
    complement (I64# x#)       = I64# (word2Int# (int2Word# x# `xor#` int2Word# (-1#)))
    (I64# x#) `shift` (I# i#)
        | i# >=# 0#            = I64# (x# `iShiftL#` i#)
        | otherwise            = I64# (x# `iShiftRA#` negateInt# i#)
    (I64# x#) `rotate` (I# i#)
        | i'# ==# 0# 
        = I64# x#
        | otherwise
        = I64# (word2Int# ((x'# `uncheckedShiftL#` i'#) `or#`
                           (x'# `uncheckedShiftRL#` (64# -# i'#))))
        where
        !x'# = int2Word# x#
        !i'# = word2Int# (int2Word# i# `and#` int2Word# 63#)
    bitSize  _                 = 64
    isSigned _                 = True

{-# RULES
"fromIntegral/a->Int64" fromIntegral = \x -> case fromIntegral x of I# x# -> I64# x#
"fromIntegral/Int64->a" fromIntegral = \(I64# x#) -> fromIntegral (I# x#)
  #-}

{-# RULES
"properFraction/Float->(Int64,Float)"
    forall x. properFraction (x :: Float) =
                      case properFraction x of {
                        (n, y) -> ((fromIntegral :: Int -> Int64) n, y) }
"truncate/Float->Int64"
    forall x. truncate (x :: Float) = (fromIntegral :: Int -> Int64) (truncate x)
"floor/Float->Int64"
    forall x. floor    (x :: Float) = (fromIntegral :: Int -> Int64) (floor x)
"ceiling/Float->Int64"
    forall x. ceiling  (x :: Float) = (fromIntegral :: Int -> Int64) (ceiling x)
"round/Float->Int64"
    forall x. round    (x :: Float) = (fromIntegral :: Int -> Int64) (round x)
  #-}

{-# RULES
"properFraction/Double->(Int64,Double)"
    forall x. properFraction (x :: Double) =
                      case properFraction x of {
                        (n, y) -> ((fromIntegral :: Int -> Int64) n, y) }
"truncate/Double->Int64"
    forall x. truncate (x :: Double) = (fromIntegral :: Int -> Int64) (truncate x)
"floor/Double->Int64"
    forall x. floor    (x :: Double) = (fromIntegral :: Int -> Int64) (floor x)
"ceiling/Double->Int64"
    forall x. ceiling  (x :: Double) = (fromIntegral :: Int -> Int64) (ceiling x)
"round/Double->Int64"
    forall x. round    (x :: Double) = (fromIntegral :: Int -> Int64) (round x)
  #-}

uncheckedIShiftL64# :: Int# -> Int# -> Int#
uncheckedIShiftL64#  = uncheckedIShiftL#

uncheckedIShiftRA64# :: Int# -> Int# -> Int#
uncheckedIShiftRA64# = uncheckedIShiftRA#
#endif

instance Real Int64 where
    toRational x = toInteger x % 1

instance Bounded Int64 where
    minBound = -0x8000000000000000
    maxBound =  0x7FFFFFFFFFFFFFFF

instance Ix Int64 where
    range (m,n)         = [m..n]
    unsafeIndex (m,_) i = fromIntegral i - fromIntegral m
    inRange (m,n) i     = m <= i && i <= n
