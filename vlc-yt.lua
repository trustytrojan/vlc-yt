json = require("dkjson")

---@param num_tabs integer
function PrintTabs(num_tabs)
	for _ = 1, num_tabs do
		io.write("\t")
	end
end

---@param tbl table
---@param indent integer
function PrintTable(tbl, indent)
	if not indent then indent = 0 end
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

---@param str string
function UrlEncode(str)
	str = string.gsub(str, "\n", "\r\n")
	str = string.gsub(str, "([^%w ])", function(c) return string.format("%%%02X", string.byte(c)) end)
	return string.gsub(str, " ", "+")
end

---@param url string
---@return table
function HttpJsonRequest(url)
	local stream = vlc.stream(url)
	return json.decode(stream:read(stream:getsize()))
end

ShellExec = {
	---Runs `command` in a shell and returns the output.
	---@param command string
	---@return string
	Output = function(command)
		local handle = io.popen(command)
		if handle == nil then
			local err_msg = "ShellExec.Output: handle is nil"
			vlc.msg.err(err_msg)
			error(err_msg)
		end
		local output = handle:read("a"):gsub("\n", "")
		handle:close()
		return output
	end,

	---@param command string
	Success = function(command)
		local _, _, code = os.execute(command)
		return code == 0
	end
}

YtSearchApi = {
	---@param port integer
	StartServer = function(port)
		YtSearchApi.ServerPid = ShellExec.Output("node ~/.local/share/vlc/lua/extensions/vlc-yt/yt-search-api.js " .. port .. " & echo $!")
		YtSearchApi.ServerUrl = "http://localhost:" .. port
	end,

	StopServer = function()
		os.execute("kill " .. YtSearchApi.ServerPid)
	end,

	---@param query string
	Search = function(query)
		return HttpJsonRequest(YtSearchApi.ServerUrl .. "/search?q=" .. UrlEncode(query))
	end,

	NextPage = function()
		return HttpJsonRequest(YtSearchApi.ServerUrl .. "/nextpage")
	end
}

function YtDlpIsInstalled()
	return ShellExec.Success("type yt-dlp >/dev/null")
end

function YoutubeDlIsInstalled()
	return ShellExec.Success("type youtube-dl >/dev/null")
end

---@param video_id string
function GetAudioStreamUrl(video_id)
	if YtDlpIsInstalled() then
		-- `ytsearch:` must be used due to the edge case of video ids starting with a `-`
		return ShellExec.Output("yt-dlp -xg ytsearch:" .. video_id)
	end

	if YoutubeDlIsInstalled() then
		-- using a full URL handles the case where some video ids start with a `-`
		return ShellExec.Output("youtube-dl -xg https://youtu.be/" .. video_id)
	end

	local error_msg = "Neither yt-dlp nor youtube-dl are installed!"
	vlc.msg.err(error_msg)
	error(error_msg)
end

---@param path string
function BindVlcPlaylistAdd(path)
	return function() vlc.playlist.add({ { path = path } }) end
end

function HideResults()
	for _, row in pairs(SearchResultRows) do
		for _, widget in pairs(row) do
			Dialog:del_widget(widget)
		end
	end
end

---@param search_results table
function ShowSearchResults(search_results)
	Dialog:add_label("Click a button to add to the playlist:", 1, 1)
	SearchResultRows = {}

	for i, result in pairs(search_results) do
		SearchResultRows[i] = {}
		SearchResultRows[i].Label = Dialog:add_label(result.channel .. " - " .. result.title, 1, i)
		SearchResultRows[i].VideoBtn = Dialog:add_button("Video", BindVlcPlaylistAdd("https://youtu.be/" .. result.id), 2, i)
		SearchResultRows[i].AudioBtn = Dialog:add_button("Audio", BindVlcPlaylistAdd(GetAudioStreamUrl(result.id)), 3, i)
	end

	Dialog:add_button("Return to Search", function() HideResults() ShowSearch() end)
end

function OnSubmitClicked()
	local spin_icon = Dialog:add_spin_icon(0)
	spin_icon:animate()
	local search_results = YtSearchApi.Search(SearchInput:get_text())
	Dialog:del_widget(spin_icon)
	HideSearch()
	ShowSearchResults(search_results)
end

function ShowSearch()
	SearchInput = Dialog:add_text_input("", 1, 1, 2)
	SearchButton = Dialog:add_button("Search", OnSubmitClicked, 1, 2, 2)
end

function HideSearch()
	Dialog:del_widget(SearchInput)
	Dialog:del_widget(SearchButton)
end

function descriptor()
	return {
		title = "vlc-yt",
		author = "trustytrojan"
	}
end

function StartExtension()
	YtSearchApi.StartServer(3000)
	ShowSearch()
end

function activate()
	Dialog = vlc.dialog("YouTube")
	Dialog:show()

	if (not YoutubeDlIsInstalled()) and (not YtDlpIsInstalled()) then
		NoticeLabel = Dialog:add_label("Neither youtube-dl not yt-dlp are on your $PATH. Audio-only streams may not be possible.")
		OkButton = Dialog:add_button("OK", function()
			Dialog:del_widget(NoticeLabel)
			Dialog:del_widget(OkButton)
			StartExtension()
		end)
	else
		StartExtension()
	end
end

function deactivate()
	YtSearchApi.StopServer()
end
