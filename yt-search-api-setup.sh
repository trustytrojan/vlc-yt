VLC_YT_PATH=~/.local/share/vlc/lua/extensions/userdata/vlc-yt

if ! cd $VLC_YT_PATH >/dev/null; then
	mkdir -p $VLC_YT_PATH
	cd $VLC_YT_PATH
fi

# at this point the cwd is $VLC_YT_PATH

if [ ! -e "node_modules" ]; then
	curl -O https://raw.githubusercontent.com/trustytrojan/vlc-yt/main/package.json
	npm i
fi

if [ ! -e "yt-search-api.js" ]; then
	curl -O https://raw.githubusercontent.com/trustytrojan/vlc-yt/main/yt-search-api.js
fi

if [ -z $1 ]; then
	echo "Server port required"
	exit 1
fi

node yt-search-api $1 & echo $!
