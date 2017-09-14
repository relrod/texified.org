{-# LANGUAGE OverloadedStrings #-}
module Main where

import Control.Monad.IO.Class
import Control.Lens hiding (index)
import Data.Aeson.Lens
import qualified Data.ByteString.Char8 as C8
import Data.Functor.Identity
import Data.Maybe (fromMaybe, listToMaybe)
import Data.Monoid
import Database.SQLite.Simple hiding ((:=))
import qualified Data.Text as T
import qualified Data.Text.Lazy as TL
import Lucid
import qualified Network.Wreq as W
import Network.Wreq (FormParam ((:=)))
import Web.Scotty

import TexifiedConfig

-- This only exists so sqlite-simple is happy
newtype PasteContent = PasteContent TL.Text
instance FromRow PasteContent where fromRow = PasteContent <$> field
instance ToRow PasteContent where toRow (PasteContent x) = toRow (Only x)

style :: Html ()
style = style_ ".serif { font-family: 'Cormorant Garamond', serif; }\
               \.pad { padding-top: 15px; padding-bottom: 15px; }\
               \.brdtop { border-top: 1px solid #ccc; margin-top: 15px; }"

navbar :: Html ()
navbar =
  nav_ [class_ "navbar navbar-static-top"] $
    div_ [class_ "container-fluid"] $
      span_ [ class_ "navbar-brand"
            , style_ "font-family: 'Cormorant Garamond', serif; font-weight: bold;"
            ] "TeXiFiEd"

footer :: Html ()
footer =
  div_ [class_ "serif pad brdtop"] $
    div_ [class_ "container"] $
      div_ [class_ "row"] $ do
        div_ [class_ "col-sm-6", style_ "float: left;"] $
          "TeXiFiEd"
        div_ [class_ "col-sm-6", style_ "text-align: right; float: left;"] $ do
          "© 2016 Ricky Elrod - "
          a_ [href_ "https://github.com/relrod/texified.org"] "source"

latexInputBox :: ToHtml a => a -> Html ()
latexInputBox def =
  textarea_ [ id_ "latex-input"
            , name_ "latex-input"
            , style_ "width: 100%;\
                     \min-height: 500px;\
                     \font-family: monospace;"
            ] (toHtml def)

latexRenderBox :: ToHtml a => a -> Html ()
latexRenderBox str = div_ [ id_ "render"
                          , class_ "serif"
                          ] (toHtml str)

latexRenderScript :: Html ()
latexRenderScript = do
  script_ [type_ "text/x-mathjax-config"] (T.pack "MathJax.Hub.Config({tex2jax: {inlineMath: [['$','$']]}})")
  script_ "function render_latex() {\
          \  $('#render').html($('#latex-input').val());\
          \  $('#render').html($('#render').html().replace(/\\n/g, '<br />'));\
          \  MathJax.Hub.Queue(['Typeset',MathJax.Hub,document.getElementById('render')]);\
          \}"
  script_ "$(function() {\
          \  render_latex(); /* Do a render after the DOM is loaded, in case we have default text */\
          \  $('#latex-input').bind('input propertychange', function() {\
          \    window.clearTimeout($(this).data('timeout'));\
          \    $(this).data('timeout', setTimeout(function () {\
          \      render_latex();\
          \    }, 700));\
          \  });\
          \});"

index :: TL.Text -> Maybe (HtmlT Identity ()) -> Html ()
index def msg =
  div_ [class_ "container-fluid"] $
    div_ [class_ "row"] $ do
      div_ [class_ "col-sm-6"] $ do
        fromMaybe (toHtml ("" :: String)) msg
        form_ [method_ "post"] $ do
          latexInputBox def
          div_ $ do
            div_ [ class_ "g-recaptcha"
                 , data_ "sitekey" "6LfU8wkUAAAAAGVS4b189KoTgETVYBzmePzRTStj"
                 , style_ "float: left;"
                 ] ""
            input_ [ type_ "submit"
                   , class_ "btn btn-success"
                   , style_ "float: left;"
                   ]
      div_ [class_ "col-sm-6"] $
        latexRenderBox ("" :: String)

chrome :: HtmlT Identity a -> ActionM ()
chrome h =
  html . renderText $
    doctypehtml_ $ do
      head_ $ do
        meta_ [charset_ "utf-8"]
        meta_ [name_ "viewport", content_ "width=device-width, initial-scale=1"]
        title_ "TeXiFiEd: A modern, LaTeX-rendering pastebin."
        link_ [rel_ "stylesheet", href_ "https://cdnjs.cloudflare.com/ajax/libs/twitter-bootstrap/4.0.0-alpha.5/css/bootstrap.min.css"]
        link_ [rel_ "stylesheet", href_ "https://fonts.googleapis.com/css?family=Cormorant+Garamond"]
        style
        script_ [src_ $ T.pack "https://cdnjs.cloudflare.com/ajax/libs/jquery/3.1.1/jquery.min.js"] (T.pack "")
        script_ [src_ "https://cdnjs.cloudflare.com/ajax/libs/twitter-bootstrap/4.0.0-alpha.5/js/bootstrap.min.js"] (T.pack "")
        script_ [src_ "https://cdnjs.cloudflare.com/ajax/libs/mathjax/2.7.1/MathJax.js?config=TeX-AMS-MML_HTMLorMML"] (T.pack "")
        script_ [src_ "https://www.google.com/recaptcha/api.js"] (T.pack "")
        latexRenderScript
      body_ $ do
        navbar
        h
        footer

alert :: T.Text -> T.Text -> HtmlT Identity ()
alert cls msg =
  div_ [class_ ("alert alert-" `mappend` cls), role_ "alert"] (toHtml msg)

verifyCaptcha :: String -> IO Bool
verifyCaptcha response = do
  r <- W.post "https://www.google.com/recaptcha/api/siteverify"
       [ ("secret" :: C8.ByteString) := captchaSecret
       , "response" := response
       ]
  let f = r ^? W.responseBody . key "success" . _Bool
  return (fromMaybe False f)

handlePost :: ActionM ()
handlePost = do
  input <- param "latex-input"
  captchaResponse <- param "g-recaptcha-response"
  captchaSuccess <- liftIO $ verifyCaptcha captchaResponse
  if not captchaSuccess
    then chrome (index input (Just (alert "danger" "Captcha failed")))
    else do
      pid <- liftIO $ storePaste input
      redirect $ TL.pack "/p/" `mappend` (TL.pack . show $ pid)
  where
    storePaste input = do
      conn <- open dbPath
      execute conn "insert into pastes (content) values (?);" (PasteContent input)
      lastInsertRowId conn

getPaste :: Integer -> IO (Maybe PasteContent)
getPaste pid = do
  conn <- open dbPath
  listToMaybe <$> query conn "select content from pastes where id=?" (Only pid)

renderPaste :: ActionM ()
renderPaste = do
  pid <- param "pid"
  paste <- liftIO $ getPaste pid
  chrome $
    div_ [class_ "container"] $
      div_ [class_ "row"] $
        div_ [class_ "col-sm-12"] $
          case paste of
            Just (PasteContent p) -> latexRenderBox p
            Nothing -> alert "danger" "That paste id wasn't found! :("

main :: IO ()
main = scotty 3001 $ do
  get "/" $ chrome (index "" Nothing)
  get "/p/:pid" renderPaste
  post "/" handlePost
