module Hbro.Keys.Signals where

-- {{{ Imports
import Hbro.Error
-- import Hbro.Gdk.KeyVal
import Hbro.Keys as Keys
import Hbro.Keys.Model hiding(KeyStroke)
import Hbro.Logger
import Hbro.Prelude

import Control.Lens.Getter
import Control.Monad.Reader hiding(forM_)
-- }}}

data KeyPressed = KeyPressed KeyStroke


dequeue :: (BaseIO m) => a -> TMVar KeyPressed -> Keys.Hooks (ExceptT Text (ReaderT a m)) -> m ()
dequeue globalContext signal hooks = forever $ do
    -- debugM "hbro.hooks" "Listening for key-pressed signal..."
    (KeyPressed stroke) <- atomically $ takeTMVar signal
    theStatus           <- atomically $ readTVar (hooks^.statusL)

    let newStatus    = press stroke theStatus
        newChain     = newStatus^.keyStrokesL
        f            = getBoundFunction newStatus

    debugM "hbro.hooks" $ "Key pressed signal acknowledged: " ++ unwords (map describe newChain)

    g <- atomically . tryReadTMVar $ hooks^.onKeyPressedL
    forM_ g $ \g' -> do
        debugM "hbro.hooks" "Global callback defined, executing it."
        (`runReaderT` globalContext) . logErrors_ $ g' newChain

    forM_ f $ \f' -> do
        debugM "hbro.hooks" "Key is bound, executing callback..."
        (`runReaderT` globalContext) . logErrors_ $ f'

    atomically . modifyTVar (hooks^.statusL) $ const newStatus