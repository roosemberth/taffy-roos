{- Copyright (C) 2019 Roosembert Palacios

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
-}

{-# LANGUAGE OverloadedStrings #-}
module Main where

import           Control.Applicative
import           Control.Monad (guard, liftM)
import           Control.Monad.IO.Class (liftIO, MonadIO)
import           Data.Bool (bool)
import qualified Data.Maybe as DM
import           Data.Text (Text)
import qualified Data.Text as T

import qualified GI.Gtk

import           System.Environment.XDG.BaseDir (getUserConfigFile)
import           System.Directory (doesFileExist)
import           System.IO (FilePath)

import           System.Taffybar
import           System.Taffybar.Context (TaffyIO)
import           System.Taffybar.Hooks
import           System.Taffybar.Information.CPU
import           System.Taffybar.Information.Memory
import           System.Taffybar.SimpleConfig
import           System.Taffybar.Util
import           System.Taffybar.Widget
import           System.Taffybar.Widget.Generic.PollingGraph
import           System.Taffybar.Widget.Generic.PollingLabel
import           System.Taffybar.Widget.Layout
import           System.Taffybar.Widget.Util
import           System.Taffybar.Widget.Workspaces

import           Paths_taffy_roos

transparent = (0.0, 0.0, 0.0, 0.0)
green1 = (0, 1, 0, 1)
green2 = (1, 0, 1, 0.5)

myGraphConfig = defaultGraphConfig
  { graphPadding = 0
  , graphBorderWidth = 0
  , graphWidth = 75
  , graphBackgroundColor = transparent
  , graphLabel = Nothing
  }

cpuCfg = myGraphConfig { graphDataColors = [green1, green2] }

cpuCallback = do
  (_, systemLoad, totalLoad) <- cpuLoad
  return [totalLoad, systemLoad]

customLayoutTitle title = text
  where text = if "Tabbed" `T.isPrefixOf` title
                then highlight "00FF00" (T.drop 7 title)
                else highlight "FF0000" title
        highlight color text = T.pack $ "<span fgcolor='#" ++ color ++ "'>" ++ T.unpack text ++ "</span>"

formatMemoryUsageRatio :: Double -> Text
formatMemoryUsageRatio n = T.pack $ "⛦: " ++ show (roundInt (n * 100)) ++ "%"
  where roundInt = round :: Double -> Int

getResource :: String -> IO (Maybe FilePath)
getResource name = firstJust <$> sequence [xdgResource name, staticResource name]
  where onlyIfExists filePath = bool Nothing (Just filePath) <$> doesFileExist filePath
        xdgResource name = getUserConfigFile "taffybar" name >>= onlyIfExists
        staticResource name = getDataFileName name >>= onlyIfExists
        firstJust = DM.listToMaybe . DM.catMaybes . filter DM.isJust

myCmdPoll :: MonadIO m => Double -> Text -> String -> m GI.Gtk.Widget
myCmdPoll interval def cmdline = pollingLabelNew interval cmdOutput
  where cmdOutput = T.filter (/= '\n') <$> (runCommand "sh" ["-c", cmdline] >>= processOutput)
        processOutput = either (return . const def) (return . T.pack)

routeInfo = myCmdPoll 5 "nogw" cmdline
  where cmdline = "default-routes.sh" |> replaceNetAliasesCmd |> mergeCmd
        replaceNetAliasesCmd = "awk " ++ awkcmd ++ " " ++ netAliasesPath ++ " -"
          where awkcmd = "'NR==FNR{map[$1]=$2;next}{for (i in map) gsub(i,map[i]); print $0}'"
        netAliasesPath = "/home/roosemberth/.local/var/lib/taffybar-net-lut"
        mergeCmd = "paste -s -d ',' | sed 's/,/, /g'"
        a |> b = a ++ " | " ++ b

-- Widgets
currentWindow = windowsNew defaultWindowsConfig
layout = layoutNew $ LayoutConfig $ return . customLayoutTitle
network = networkMonitorNew defaultNetFormat $ Just ["wlp2s0", "enp0s31f6"]
ping = myCmdPoll 5 "✈" "ping -w 5 -c 1 orbstheorem.ch | grep -oP 'time=\\K.*'"
screenTimeout = myCmdPoll 1 "?" "xset q | awk '/Saver/{a=1} a && /time/{print $4; exit}'"
task = myCmdPoll 1 "None" "timew :yes get dom.active.{duration,tag.1,tag.2}"
-- See https://github.com/taffybar/gtk-sni-tray#statusnotifierwatcher for a better way to set up the sni tray
tray = sniTrayThatStartsWatcherEvenThoughThisIsABadWayToDoIt
workspaces = workspacesNew $ defaultWorkspacesConfig
  { minIcons = 0
  , widgetGap = 0
  , showWorkspaceFn = hideEmpty
  , urgentWorkspaceState = True
  , getWindowIconPixbuf = scaledWindowIconPixbufGetter getWindowIconPixbufFromEWMH
  }

-- Application configuration
myConfig = SimpleTaffyConfig
  { monitorsAction = useAllMonitors
  , barHeight = 30
  , barPadding = 0
  , barPosition = Top
  , widgetSpacing = 1
  , startWidgets = [task] ++ map (>>= buildContentsBox) [layout] ++ [workspaces]
  , centerWidgets = map (>>= buildContentsBox) [currentWindow]
  , endWidgets = map (>>= buildContentsBox)
    [ textClockNew Nothing "%a %b %_d %H:%M:%S" 1
    , batteryIconNew
    , textBatteryNew "$percentage$ ($time$)"
    , tray
    , pollingLabelNew 1 $ formatMemoryUsageRatio . memoryUsedRatio <$> parseMeminfo
    , pollingGraphNew cpuCfg 0.5 cpuCallback
    , fsMonitorNew 500 ["/"]
    , screenTimeout
    , ping
    , routeInfo
    , network
    , mpris2New
    ]
  , cssPath = Nothing
  , startupHook = return ()
  }

main = do
  cssPath <- getResource "taffybar.css"
  dyreTaffybarMain $ withBatteryRefresh $ withLogServer $ withToggleServer $
                     toTaffyConfig myConfig {cssPath = cssPath}
