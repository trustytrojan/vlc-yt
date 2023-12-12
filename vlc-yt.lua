json = require("dkjson")

---@param str string
function UrlEncode(str)
	str = string.gsub(str, "\n", "\r\n")
	str = string.gsub(str, "([^%w ])", function(c) return string.format("%%%02X", string.byte(c)) end)
	return string.gsub(str, " ", "+")
end

---@param url string
---@return table|string|number|boolean|nil
function HttpJsonRequest(url)
	local stream = vlc.stream(url)
	return json.decode(stream:read(stream:getsize()))
end

Log = {
	Debug = function(s)
		vlc.msg.dbg("vlc-yt: " .. s)
	end,

	Error = function(s)
		vlc.msg.err("vlc-yt: " .. s)
	end
}

ShellExec = {
	---Runs `command` in a shell and returns the output.
	---@param command string
	---@return string
	Output = function(command)
		local handle, errmsg = io.popen(command)

		if (not handle) or errmsg then
			errmsg = "ShellExec.Output: " .. errmsg
			vlc.msg.err(errmsg)
			error(errmsg)
		end

		local read_mode
		if _VERSION == "Lua 5.2" then
			-- Tested only on 5.2, this may be required on older versions as well
			read_mode = "*a"
		else
			read_mode = "a"
		end

		-- remove trailing newlines
		local output = handle:read(read_mode):gsub("\n*$", "")
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
		YtSearchApi.ServerUrl = "http://localhost:" .. port

		-- ping existing server, if it fails, start a new server
		if not pcall(function() YtSearchApi.GetJson("/ping") end) then
			vlc.msg.info("ping failed, starting new server at port " .. port)
			-- the git repo is expected to be at ~/.local/share/vlc/lua/extensions/vlc-yt
			os.execute("node ~/.local/share/vlc/lua/extensions/vlc-yt/yt-search-api.js " .. port .. " &")
		end
	end,

	---@param route string
	---@return table|string|number|boolean|nil
	GetJson = function(route)
		local stream = vlc.stream(YtSearchApi.ServerUrl .. route)
		return json.decode(stream:read(stream:getsize()))
	end,

	---@param query string
	Search = function(query)
		return YtSearchApi.GetJson("/search?q=" .. UrlEncode(query))
	end,

	NextPage = function()
		local value = YtSearchApi.GetJson("/nextpage")
		if type(value) ~= "table" then
			Log.Error("YtSarchApi.NextPage: value is not a table")
		end
	end
}

function YtDlpIsInstalled()
	return ShellExec.Success("type yt-dlp &>/dev/null")
end

function YoutubeDlIsInstalled()
	return ShellExec.Success("type youtube-dl &>/dev/null")
end

---@param video_id string
function GetAudioStreamUrl(video_id)
	Log.Debug("getting audio stream url for video id: " .. video_id)

	if video_id:sub(1, 1) == "-" then
		video_id = "https://youtu.be/" .. video_id
	end

	if YtDlpIsInstalled() then
		return ShellExec.Output("yt-dlp -xg " .. video_id)
	end

	if YoutubeDlIsInstalled() then
		return ShellExec.Output("youtube-dl -xg " .. video_id)
	end

	Log.Error("Neither yt-dlp nor youtube-dl are installed!")
end

function HideResults()
	for _, row in pairs(SearchResultRows) do
		for _, widget in pairs(row) do
			Dialog:del_widget(widget)
		end
	end
	Dialog:del_widget(NextPageBtn)
	Dialog:del_widget(ReturnToSearchBtn)
end

---@param search_results table
function ShowResults(search_results)
	Dialog:set_title("YouTube Search Results")
	SearchResultRows = {}

	for i, result in pairs(search_results) do
		-- TODO: Try to make search results look better
		SearchResultRows[i] = {}
		SearchResultRows[i].Label = Dialog:add_label(result.channel .. " - " .. result.title, 1, i)
		SearchResultRows[i].VideoBtn = Dialog:add_button("Video", function() vlc.playlist.add({ { path = "https://youtu.be/" .. result.id } }) end, 2, i)
		SearchResultRows[i].AudioBtn = Dialog:add_button("Audio", function() vlc.playlist.add({ { path = GetAudioStreamUrl(result.id) } }) end, 3, i)
	end

	NextPageBtn = Dialog:add_button("Next Page", function()
		local search_results_2
		SpinWhile(function() search_results_2 = YtSearchApi.NextPage() end)
		HideResults()
		ShowResults(search_results_2)
	end, 1, #search_results + 1, 3)

	ReturnToSearchBtn = Dialog:add_button("Return to Search", function()
		HideResults()
		ShowSearch()
	end, 1, #search_results + 2, 3)
end

---Adds a spin icon to `Dialog`, calls `func`, then removes the spin icon.
---@param func function
function SpinWhile(func)
	local spin_icon = Dialog:add_spin_icon(0)
	spin_icon:animate()
	Dialog:update()
	func()
	Dialog:del_widget(spin_icon)
end

function ShowSearch()
	Dialog:set_title("YouTube Search")
	SearchInput = Dialog:add_text_input("", 1, 1, 2)
	SearchButton = Dialog:add_button("Search", function()
		local query = SearchInput:get_text()
		if query == "" then return end
		local search_results
		SpinWhile(function() search_results = YtSearchApi.Search(query) end)
		HideSearch()
		ShowResults(search_results)
	end, 1, 2, 2)
end

function HideSearch()
	Dialog:del_widget(SearchInput)
	Dialog:del_widget(SearchButton)
end

function StartExtension()
	YtSearchApi.StartServer(3000)
	ShowSearch()
end

function descriptor()
	return {
		title = "vlc-yt",
		author = "trustytrojan"
	}
end

function activate()
	Dialog = vlc.dialog("vlc-yt")
	Dialog:show()

	if (not YoutubeDlIsInstalled()) and (not YtDlpIsInstalled()) then
		local message = "Neither youtube-dl nor yt-dlp were found on your $PATH. Audio-only streams will not work. To enable audio-only streams, install either yt-dlp (highly recommended) or youtube-dl (outdated, not all videos will work), and reload the extension."
		vlc.msg.warn(message)
		NoticeLabel = Dialog:add_label(message)
		OkButton = Dialog:add_button("OK", function()
			Dialog:del_widget(NoticeLabel)
			Dialog:del_widget(OkButton)
			StartExtension()
		end)
	else
		StartExtension()
	end
end
