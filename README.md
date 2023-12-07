# vlc-yt
A YouTube search extension for VLC media player.

## Installation
On Linux, run the following commands in your terminal:
```sh
cd ~/.local/share/vlc/lua/extensions
git clone https://github.com/trustytrojan/vlc-yt
ln -sf $PWD/vlc-yt/vlc-yt.lua
```
On Windows, `git` is required. If you don't have `git` installed, the fastest way is to run `winget install mingit`. Run the following in Command Prompt or Powershell **with elevated permissions** (to allow the use of `mklink`):
```cmd
cd %AppData%\vlc\lua\extensions
git clone https://github.com/trustytrojan/vlc-yt
mklink vlc-yt.lua %cwd%\vlc-yt\vlc-yt.lua
```
If you cannot acquire elevated permissions, replace the last command with:
```cmd
copy vlc-yt\vlc-yt.lua .
```
The reason for creating a symbolic link is to have one less command to run when updating `vlc-yt`.

## Updating vlc-yt
Simply `cd` to the cloned repository on your system, and run `git pull`.
On Linux:
```sh
cd ~/.local/share/vlc/lua/extensions/vlc-yt
git pull
```
On Windows:
```cmd
cd %AppData%\vlc\lua\extensions\vlc-yt
git pull
```

## Usage
Run VLC. Click the `View` Menu and select `vlc-yt` to activate the extension.
