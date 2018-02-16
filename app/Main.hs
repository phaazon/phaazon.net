import Control.Concurrent.STM.TVar (newTVarIO)
import Data.Yaml (decodeFileEither)
import Network.Wai.Handler.Warp (defaultSettings, runSettings, setLogger, setPort)

import Blog (defaultBlogEntryMapping, refreshBlog)
import FileBrowser (defaultPubList, refreshBrowserFiles)
import ServerConfig (ServerConfig(..))
import System.Directory (createDirectoryIfMissing)
import WebApp (webApp)

main :: IO ()
main = do
  eitherConf <- decodeFileEither "server.yaml"

  case eitherConf of
    Left e -> print e
    Right conf -> do
      let port = configPort conf
      let uploadDir = configUploadDir conf
      let blogManifestPath = configBlogEntriesPath conf

      putStrLn $ "starting server on port " ++ show port

      -- create the directory to contain uploads if it doesn’t exist yet
      createDirectoryIfMissing True uploadDir

      -- create a TVar to hold browser’s files; those will get reloaded everytime a new file is pushed
      -- and at initialization
      filesTVar <- newTVarIO defaultPubList
      refreshBrowserFiles filesTVar

      -- create a TVar to hold the blog’s entries
      blogTVar <- newTVarIO defaultBlogEntryMapping
      refreshBlog blogManifestPath blogTVar

      let serverSettings = setLogger logger . setPort (fromIntegral port) $ defaultSettings
          logger req st _ = putStrLn $ show st ++ " | " ++ show req ++ "\n"
      runSettings serverSettings (webApp filesTVar uploadDir blogManifestPath blogTVar)
