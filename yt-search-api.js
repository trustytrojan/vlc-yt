import { GetListByKeyword, NextPage } from "youtube-search-api";
import { argv, exit } from "process";
import express from "express";

if (argv.length != 3) {
	console.error("Arguments: <port>");
	exit(1);
}

const minifySearchResult = (result) => {
	/** @type {{ items: any[], nextPage: any }} */
	const minResult = { items: [], nextPage: result.nextPage };
	for (const item of result.items) {
		if (item.type !== "video") continue;
		minResult.items.push({
			id: item.id,
			//type: item.type,
			//thumbnail_url: item.thumbnail.thumbnails[0].url,
			title: item.title,
			channel: item.channelTitle,
			//length: item.length.simpleText,
			//is_live: item.isLive
		});
	}
	return minResult;
};

// stores the current search result returned by `minifySearchResult`
let currentResult;

const app = express();

app.get("/ping", (_, res) => res.json("pong"));

// Expects a `q` query parameter containing the YouTube search query
app.get("/search", async (req, res) => res.json((currentResult = minifySearchResult(await GetListByKeyword(req.query.q, false, 5))).items));

// Returns the next page of search results based on the initial `/search` call
app.get("/nextpage", async (_, res) => res.json((currentResult = minifySearchResult(await NextPage(currentResult.nextPage, false, 5))).items));

const port = Number.parseInt(argv[2]);
app.listen(port);
console.log(`Listening on ${port}`);
