{-# LANGUAGE CPP #-}
{-# LANGUAGE TemplateHaskell #-}
{-# OPTIONS_GHC -O2 -ddump-splices #-}
import Data.Int (Int64)
import System.Environment (getArgs)
import Control.Monad.Par.Meta.Dist (longSpawn, runParDist, runParSlave, Par, get)
import Control.Monad.IO.Class (liftIO)
-- Tweaked version of CloudHaskell's closures:
import Remote2.Call (mkClosureRec, remotable)

--------------------------------------------------------------------------------

type FibType = Int64

-- Par monad version + distributed execution:
parfib1 :: FibType -> Par FibType
parfib1 n | n < 2 = return 1
parfib1 n = do 
    liftIO $ putStrLn $ " PARFIB "++show n
    xf <- longSpawn $ $(mkClosureRec 'parfib1) (n-1)
    y  <-             parfib1 (n-2)
    x  <- get xf
    return (x+y)

-- Generate stub code for RPC:
remotable ['parfib1]

main = do 
    args <- getArgs
    let (version, size, cutoff) = case args of 
            []      -> ("master", 3, 1)
            [v]     -> (v,        3, 1)
            [v,n]   -> (v, read n,   1)
            [v,n,c] -> (v, read n, read c)

    case version of 
        "slave" -> runParSlave [__remoteCallMetaData]
        "master" -> do 
		       putStrLn "Using non-thresholded version:"
		       ans <- (runParDist [__remoteCallMetaData] (parfib1 size) :: IO FibType)
		       putStrLn $ "Final answer: " ++ show ans
        str -> error$"Unhandled mode: " ++ str
