{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE StrictData #-}
{-# LANGUAGE TypeOperators #-}

module Blog (
    BlogApi
  , BlogEntry(..)
  , BlogEntryMapping(..)
  , blog
  , defaultBlogEntryMapping
  , refreshBlog
  ) where

import Control.Concurrent.Async (async)
import Control.Concurrent.STM (atomically)
import Control.Concurrent.STM.TVar (TVar, readTVarIO, writeTVar)
import Control.Monad (void)
import Control.Monad.IO.Class (MonadIO(..))
import Data.Aeson (FromJSON)
import Data.Either (fromRight)
import Data.Foldable (traverse_)
import Data.HashMap.Strict (HashMap)
import qualified Data.HashMap.Strict as H
import Data.List (intersperse, sortBy)
import Data.Ord (comparing)
import Data.Text (Text)
import qualified Data.Text.IO as T
import Data.Time (UTCTime, getCurrentTime)
import Data.Traversable (for)
import Data.Yaml (ParseException, decodeFileEither)
import GHC.Generics (Generic)
import Prelude hiding (div, span)
import Servant ((:>), (:<|>)(..), Capture, Get)
import Servant.HTML.Blaze (HTML)
import Servant.Server (Server)
import System.FilePath (takeExtension)
import Text.Blaze.Html5 hiding (style)
import Text.Blaze.Html5.Attributes hiding (async, content, for, span)

import Markup (Markup(..), markupToHtml)
import Wrapper (wrapper)

type BlogApi =
       Get '[HTML] Html
  -- :<|> "rss" :> Get '[XML]
  :<|> Capture "slug" Text :> Get '[HTML] Html

-- The blog entries configuration.
newtype BlogEntryManifest = BlogEntryManifest {
    getEntries :: [BlogEntry]
  } deriving (Eq, FromJSON, Show)

-- A blog entry.
--
-- It has metadata so that we know when it was written, modified, etc.
data BlogEntry = BlogEntry {
    -- Name of the entry. It’s used in listings, for instance.
    blogEntryName :: Text
    -- Path to the Markdown-formatted article.
  , blogEntryPath :: FilePath
    -- Date when the article was published.
  , blogEntryPublishDate :: UTCTime
    -- Some tags.
  , blogEntryTags :: [Text]
    -- Slug used in URL to refer to that article.
  , blogEntrySlug :: Text
  } deriving (Eq, Generic, Show)

instance FromJSON BlogEntry where

-- Generate the Html from a BlogEntry.
blogEntryToHtml :: (MonadIO m) => BlogEntry -> m Html
blogEntryToHtml entry =
    case takeExtension path of
      ".md" -> fmap (fromRight "" . markupToHtml Markdown) . liftIO $ T.readFile path
      ".org" -> fmap (fromRight "" . markupToHtml Org) . liftIO $ T.readFile path
      _ -> do
        liftIO . putStrLn $ "entry " <> path <> " has an unknown markup extension"
        pure ""
  where
    path = blogEntryPath entry

-- Read the blog entry manifest from a file.
readBlogEntryManifest :: (MonadIO m) => FilePath -> m (Either ParseException BlogEntryManifest)
readBlogEntryManifest = liftIO . decodeFileEither

-- The internal structure that maps the HTML to a given blog entry.
data BlogEntryMapping = BlogEntryMapping {
    blogEntryMap :: HashMap Text (BlogEntry, Html),
    blogLastUpdateDate :: Maybe UTCTime
  }

defaultBlogEntryMapping :: BlogEntryMapping
defaultBlogEntryMapping = BlogEntryMapping mempty Nothing

-- Asynchronously read all the articles and return the HTML representation.
refreshBlog :: (MonadIO m) => FilePath -> TVar BlogEntryMapping -> m ()
refreshBlog manifestPath blogEntryTVar = void . liftIO . async $ do
  liftIO . putStrLn $ "refreshing blog (" ++ manifestPath ++ ")"
  manif <- readBlogEntryManifest manifestPath
  case manif of
    Left e -> liftIO (print e)
    Right manif' -> do
      -- we render all entries and regenerate the hashmap
      entries <- fmap H.fromList . for (getEntries manif') $ \entry -> do
        content <- blogEntryToHtml entry
        pure (blogEntrySlug entry, (entry, content))

      now <- liftIO getCurrentTime

      let entryMap = BlogEntryMapping entries (Just now)

      liftIO . atomically $ writeTVar blogEntryTVar entryMap

blog :: TVar BlogEntryMapping -> Server BlogApi
blog blogEntryMapping =
       blogMainView blogEntryMapping
  :<|> blogEntry blogEntryMapping

blogMainView :: TVar BlogEntryMapping -> Server (Get '[HTML] Html)
blogMainView blogEntryMapping = do
    entries <- liftIO (readTVarIO blogEntryMapping)
    wrapper "Blog" $ do
      section ! class_ "container section content" $ do
        h1 ! class_ "title" $ do
          b "Dimitri Sabadie"
          "’s blog"
        h2 ! class_ "subtitle" $ em $ "Functional programming, graphics, demoscene and more!"
        hr
        p $ do
          "This is my blog. I talk about functional programming, graphics, demoscene, optimization "
          "and many other topics!"
        blockquote $ do
          "It is intentional that no comment can be written by readers to prevent flooding, scams "
          "and spamming."
        p $ do
          text "Feel free to subscribe to the "
          rssLink
          text " to be notified when a new article is released!"
        hr
        traverse_ (blogListing . fst) (sortBy sorter . H.elems $ blogEntryMap entries)
  where
    sorter = flip $ comparing (blogEntryPublishDate . fst)

blogListing :: BlogEntry -> Html
blogListing entry = do
  div ! class_ "level" $ do
    span ! class_ "level-left" $ do
      span ! class_ "level-item" $
        a ! href (toValue $ "blog/" <> blogEntrySlug entry) $ toHtml (blogEntryName entry)

    span ! class_ "level-right" $ do
      span ! class_ "level-item" $ em $ "on " <> toHtml (show $ blogEntryPublishDate entry)

blogEntry :: TVar BlogEntryMapping -> Text -> Server (Get '[HTML] Html)
blogEntry blogEntryMapping slug = do
  entries <- liftIO (readTVarIO blogEntryMapping)
  case H.lookup slug (blogEntryMap entries) of
    Just (entry, rendered) -> do
      let entryName = blogEntryName entry
          tags = renderTags entry
      wrapper entryName $ do
        section ! class_ "section container" $ do
          h1 ! class_ "title" $ toHtml entryName
          h2 ! class_ "subtitle" $ em tags
          h2 ! class_ "subtitle" $ do
            toHtml (show $ blogEntryPublishDate entry) <> ", by Dimitri Sabadie — "
            rssLink
          hr
          div ! class_ "content blog-content" $ rendered

    Nothing -> wrapper "Article not found" $ pure ()

renderTags :: BlogEntry -> Html
renderTags entry = sequence_ (fmap toHtml . intersperse ", " $ blogEntryTags entry)

rssLink :: Html
rssLink = a ! href "/blog/feed" $ do
  span ! class_ "icon rss-feed" $ i ! class_ "fa fa-rss" $ pure ()
  text "feed"
