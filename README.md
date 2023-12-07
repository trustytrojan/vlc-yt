# vlc-yt
A YouTube search extension for VLC media player.

## Installation
On Linux, run the following commands in your terminal:
```sh
cd ~/.local/share/vlc/lua/extensions
git clone https://github.com/trustytrojan/vlc-yt
ln -sf $PWD/vlc-yt/vlc-yt.lua
```
On Windows, `git` is required. Run the following in Command Prompt or Powershell *with elevated permissions* (to allow the use of `mklink`):
```cmd
cd %AppData%\vlc\lua\extensions
git clone https://github.com/trustytrojan/vlc-yt
mklink vlc-yt.lua %cwd%\vlc-yt\vlc-yt.lua
```
If you cannot acquire elevated permissions, replace the last command with:
```cmd
copy vlc-yt\vlc-yt.lua .
```

## Usage
Run VLC. Click the `View` Menu and select `vlc-yt` to activate the extension.
