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

---@param str string
function UrlEncode(str)
	str = string.gsub(str, "\n", "\r\n")
	str = string.gsub(str, "([^%w ])", function(c) return string.format("%%%02X", string.byte(c)) end)
	return string.gsub(str, " ", "+")
end

---@param url string
function HttpRequest(url)
	local stream = vlc.stream(url)
	return stream:read(stream:getsize())
end

---@param url string
function HttpJsonRequest(url)
	return json.decode(HttpRequest(url))
end

---@param command string
function ShellExecOutput(command)
	local handle = io.popen(command)
	if handle == nil then
		print("ShellExec: handle is nil")
		error("handle is nil")
	end
	local output = handle:read("a"):gsub("\n", "")
	handle:close()
	return output
end

---@param command string
function ShellExecSuccess(command)
	local _, _, code = os.execute(command)
	return code == 0
end

YtSearchApi = {
	---@param port integer
	StartServer = function(port)
		YtSearchApi.ServerPid = ShellExecOutput("source yt-search-api-setup.sh " .. port)
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
	return ShellExecSuccess("type yt-dlp")
end

function YoutubeDlIsInstalled()
	return ShellExecSuccess("type youtube-dl")
end

---@param video_id string
function GetAudioStreamUrl(video_id)
	if YtDlpIsInstalled() then
		-- `ytsearch:` must be used due to the edge case of video ids starting with a `-`
		return ShellExecOutput("yt-dlp -xg ytsearch:" .. video_id)
	end

	if YoutubeDlIsInstalled() then
		-- using a full URL handles the case where some video ids start with a `-`
		return ShellExecOutput("youtube-dl -xg https://youtu.be/" .. video_id)
	end

	error("Neither yt-dlp nor youtube-dl are installed!")
end

---@param path string
function BindVlcPlaylistAdd(path)
	return function() vlc.playlist.add({ { path = path } }) end
end

---@param items table
function ShowResults(items)
	Dialog:add_label("Click a button to add to the playlist:", 1, 1)

	for idx, item in ipairs(items) do
		Dialog:add_label(item.channel .. " - " .. item.title, 1, idx)
		Dialog:add_button("Video", BindVlcPlaylistAdd("https://youtu.be/" .. item.id), 2, idx)
		Dialog:add_button("Audio", BindVlcPlaylistAdd(GetAudioStreamUrl(item.id)), 3, idx)
	end
end

function OnSubmitClicked()
	SpinIcon = Dialog:add_spin_icon(0)
	SpinIcon:animate()
	local items = YtSearchApi.Search(SearchInput:get_text())
	Dialog:del_widget(SpinIcon)
	HideSearch()
	ShowResults(items)
end

function ShowSearch()
	SearchLabel = Dialog:add_label("Search:", 1, 1)
	SearchInput = Dialog:add_text_input("", 2, 1)
	SearchButton = Dialog:add_button("Submit", OnSubmitClicked, 1, 2, 2)
end

function HideSearch()
	Dialog:del_widget(SearchLabel)
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
	Dialog = vlc.dialog("YouTube Search")
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
