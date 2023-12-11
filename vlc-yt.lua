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
---@return string
function HttpRequest(url)
	local stream = vlc.stream(url)
	return stream:read(stream:getsize())
end

---@param url string
---@return table
function HttpJsonRequest(url)
	return json.decode(HttpRequest(url))
end

ShellExec = {
	---Runs `command` in a shell and returns the output.
	---@param command string
	---@return string
	Output = function(command)
		local handle, errmsg = io.popen(command)
		if (not handle) or errmsg then
			errmsg = "ShellExec.Output: " .. errmsg
			print(errmsg)
			vlc.msg.err(errmsg)
			error(errmsg)
		end
		local output = handle:read("a"):gsub("\n", "")
		handle:close()
		return output
	end,

	---Runs `command` in a shell and returns whether the exit code was 0.
	---@param command string
	Success = function(command)
		local _, _, code = os.execute(command)
		return code == 0
	end
}

YtSearchApi = {
	---@param port integer
	StartServer = function(port)
		-- kill any existing server on `port` to minimize issues
		local pid = ShellExec.Output("lsof -t -i:" .. port)
		if pid ~= "" then os.execute("kill " .. pid) end

		YtSearchApi.ServerUrl = "http://localhost:" .. port
		os.execute("node ~/.local/share/vlc/lua/extensions/vlc-yt/yt-search-api.js " .. port .. " &")
	end,

	---@param route string
	GetJson = function(route)
		return HttpJsonRequest(YtSearchApi.ServerUrl .. route)
	end,

	---@param query string
	Search = function(query)
		return YtSearchApi.GetJson("/search?q=" .. UrlEncode(query))
	end,

	NextPage = function()
		return YtSearchApi.GetJson("/nextpage")
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
	if video_id:sub(1, 1) == "-" then
		video_id = "https://youtu.be/" .. video_id
	end

	if YtDlpIsInstalled() then
		return ShellExec.Output("yt-dlp -xg " .. video_id)
	end

	if YoutubeDlIsInstalled() then
		return ShellExec.Output("youtube-dl -xg https://youtu.be/" .. video_id)
	end

	local errmsg = "Neither yt-dlp nor youtube-dl are installed!"
	print(errmsg)
	vlc.msg.err(errmsg)
	error(errmsg)
end

function HideSearchResults()
	for _, row in pairs(SearchResultRows) do
		for _, widget in pairs(row) do
			Dialog:del_widget(widget)
		end
	end
end

---@param search_results table
function ShowSearchResults(search_results)
	SearchResultRows = {}

	for i, result in pairs(search_results) do
		-- idea: make search results look better?
		SearchResultRows[i] = {}
		SearchResultRows[i].Label = Dialog:add_label(result.channel .. " - " .. result.title, 1, i)
		SearchResultRows[i].VideoBtn = Dialog:add_button("Video", function() vlc.playlist.add({ { path = "https://youtu.be/" .. result.id } }) end, 2, i)
		SearchResultRows[i].AudioBtn = Dialog:add_button("Audio", function() vlc.playlist.add({ { path = GetAudioStreamUrl(result.id) } }) end, 3, i)
	end

	ReturnToSearchBtn = Dialog:add_button("Return to Search", function()
		HideSearchResults()
		Dialog:del_widget(ReturnToSearchBtn)
		ShowSearch()
	end, 1, #search_results, 3)
end

function OnSearchClicked()
	local spin_icon = Dialog:add_spin_icon(0)
	spin_icon:animate()
	local search_results = YtSearchApi.Search(SearchInput:get_text())
	Dialog:del_widget(spin_icon)
	HideSearch()
	ShowSearchResults(search_results)
end

function ShowSearch()
	SearchInput = Dialog:add_text_input("", 1, 1, 2)
	SearchButton = Dialog:add_button("Search", OnSearchClicked, 1, 2, 2)
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
