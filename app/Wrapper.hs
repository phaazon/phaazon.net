-- |This module exports an HTML wrapper function that can be used to unify how all pages look like.
module Wrapper (
    wrapper
  ) where

import Control.Monad (void)
import Control.Monad.IO.Class (MonadIO(..))
import Data.List (intersperse)
import Data.Text (Text)
import Data.Time (getCurrentTime, toGregorian, utctDay)
import Prelude hiding (div, id, head, span)
import Text.Blaze.Html5 as H hiding (map)
import Text.Blaze.Html5.Attributes as A hiding (span)

-- |Wrapper function that must be applied to any page’s content.
wrapper :: (MonadIO m) => Text -> Html -> m Html
wrapper t cont = do
    (year, _, _) <- liftIO $ fmap (toGregorian . utctDay) getCurrentTime

    pure . docTypeHtml $ do
      head $ do
        H.title (toHtml t <> " – phaazon.net")
        meta ! charset "utf-8"
        meta ! name "viewport" ! content "width=device-width, initial-scale=1"
        link ! rel "stylesheet" ! type_ "text/css" ! href "/static/css/bulma.css"
        link ! rel "stylesheet" ! type_ "text/css" ! href "/static/css/font-awesome.min.css"
        link ! rel "stylesheet" ! type_ "text/css" ! href "/static/css/index.css"
        link ! rel "icon" ! href "/static/imgs/tus.png"
        -- code hilighting
        link ! rel "stylesheet" ! href "/static/css/highlight/styles/atom-one-dark.css"
        script ! src "/static/css/highlight/highlight.pack.js" $ ""
        script "hljs.initHighlightingOnLoad();"

      body $ do
        menuPart
        cont
        footerPart (fromIntegral year)

menuPart:: Html
menuPart =
  nav ! class_ "hero is-medium" ! id "top-header" $ do
    div ! class_ "hero-body container level has-shadow" $ do
      div ! class_ "level-item has-text-centered" $ do
        div ! class_ "content" $ do
          p $ h1 ! class_ "title is-1" $ "Dimitri Sabadie"
          p $ h2 ! class_ "subtitle is-4" $ em $ "Do not make more tools than existing problems."

      a ! href "/" ! A.title "phaazon.net" ! class_ "level-item" $ do
        span ! class_ "icon is-large" $
          i ! class_ "fa fa-home" $ pure ()

      a ! href "https://git.phaazon.net" ! A.title "git.phaazon.net" ! class_ "level-item" $ do
        span ! class_ "icon is-large" $
          i ! class_ "fa fa-code-fork" $ pure ()

      a ! href "/blog" ! A.title "/blog" ! class_ "level-item" $ do
        span ! class_ "icon is-large" $
          i ! class_ "fa fa-pencil" $ pure ()

      a ! href "/browse" ! A.title "all the memes!" ! class_ "level-item" $ do
        span ! class_ "icon is-large" $
          i ! class_ "fa fa-cloud-download" $ pure ()

footerPart :: Int -> Html
footerPart year = do
  footer ! class_ "footer" $
    div ! class_ "content has-text-centered" $ do
      p . sequence_ $ intersperse " "
        [
          a ! class_ "icon" ! href "https://github.com/phaazon" $
            i ! class_ "fa fa-github" $ pure ()
        , a ! class_ "icon" ! href "https://twitter.com/phaazon_" $
            i ! class_ "fa fa-twitter" $ pure ()
        , a ! class_ "icon" ! href "https://www.linkedin.com/in/dimitri-sabadie-97a9009b/" $
            i ! class_ "fa fa-linkedin-square" $ pure ()
        , a ! class_ "icon" ! href "https://soundcloud.com/phaazon" $
            i ! class_ "fa fa-soundcloud" $ pure ()
        , a ! class_ "icon" ! href "https://stackoverflow.com/users/1784267/phaazon" $
            i ! class_ "fa fa-stack-overflow" $ pure ()
        , a ! class_ "icon" ! href "/media/uploads/cv.pdf" $
            i ! class_ "fa fa-graduation-cap" $ pure ()
        ]
      p . sequence_ $ intersperse " · "
        [
          a ! href "http://haskell.org/" $ "Haskell"
        , a ! href "http://haskell-servant.readthedocs.io" $ "servant"
        , a ! href "http://bulma.io" $ "bulma"
        ]
      p $ void (toHtml $ "Copyright © 2014—" ++ show year ++ ", Dimitri Sabadie")
