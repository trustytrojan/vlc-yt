json = require("dkjson")

function PrintTabs(num_tabs)
	for _ = 1, num_tabs do
		io.write("\t")
	end
end

function PrintTable(tbl, indent)
	indent = indent or 0
	print("{")
	for key, value in pairs(tbl) do
		PrintTabs(indent + 1)
		io.write(key .. ": ")
		if type(value) == "table" then
			PrintTable(value, indent + 1)
		else
			print(value)
		end
	end
	PrintTabs(indent)
	print("}")
end

function UrlEncode(str)
	str = string.gsub(str, "\n", "\r\n")
	str = string.gsub(str, "([^%w ])", function(c) return string.format("%%%02X", string.byte(c)) end)
	return string.gsub(str, " ", "+")
end

function HttpJsonRequest(url)
	local stream = vlc.stream(url)
	return json.decode(stream:read(stream:getsize()))
end

YtSearchApi = {
	GetListByKeyword = function(query)
		return json.decode(ShellExec(([[node -e "require('youtube-search-api').GetListByKeyword('%s').then(console.log)"]]):format(query)))
	end
}

function ShellExec(command)
	local handle = io.popen(command)
	if handle == nil then
		print("ShellExec: handle is nil")
		error("handle is nil")
	end
	local output = handle:read("a"):gsub("\n", "")
	handle:close()
	return output
end

function GetYtAudioStreamUrl(video_id)
	return ShellExec('yt-dlp -xg ytsearch:' .. video_id)
end

function ShowResults(items)
	Dialog:add_label("Click a button to add the video to the playlist:")
	for _, item in pairs(items) do
		Dialog:add_button(
			item.channelTitle .. " - " .. item.title,
			function() vlc.playlist.add({ { path = "https://youtu.be/" .. item.id.videoId } }) end
		)
	end
end

function OnSubmitClicked()
	SpinIcon = Dialog:add_spin_icon(0)
	SpinIcon:animate()
	local items = YtSearchApi.GetListByKeyword(SearchInput:get_text())
	Dialog:del_widget(SpinIcon)
	HideSearch()
	ShowResults(items)
end

function ShowSearch()
	SearchLabel = Dialog:add_label("Search:")
	SearchInput = Dialog:add_text_input("", 2, 1)
	SearchButton = Dialog:add_button("Submit", OnSubmitClicked, 1, 2, 2)
	Dialog:show()
end

function HideSearch()
	Dialog:del_widget(SearchLabel)
	Dialog:del_widget(SearchInput)
	Dialog:del_widget(SearchButton)
end

function descriptor()
	return {
		title = "YouTube",
		author = "trustytrojan"
	}
end

function activate()
	Dialog = vlc.dialog("YouTube Search")
	ShowSearch()
end
