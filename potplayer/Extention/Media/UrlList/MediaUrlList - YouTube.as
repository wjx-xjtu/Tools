/*
	media url search by youtube

*/

//	string GetTitle() 													-> get title for UI
//	string GetVersion													-> get version for manage
//	string GetDesc()													-> get detail information
//	string GetLoginTitle()												-> get title for login dialog
//	string GetLoginDesc()												-> get desc for login dialog
//	string ServerCheck(string User, string Pass) 						-> server check
//	string ServerLogin(string User, string Pass) 						-> login
//	void ServerLogout() 												-> logout
//	array<dictionary> GetCategorys()									-> get category list
//	string GetSorts(string Category, string Extra, string PathToken, string Query)									-> get sort option
//	array<dictionary> GetUrlList(string Category, string Extra, string PathToken, string Query, string PageToken)	-> get url list for Category

string GetTitle()
{
return "{$CP949=유튜브$}{$CP0=YouTube$}";
}

string GetVersion()
{
	return "1";
}

string GetDesc()
{
	return "https://www.youtube.com/";
}

array<dictionary> GetCategorys()
{
	array<dictionary> ret;
	
	dictionary item1;
	item1["title"] = "{$CP949=가장 인기 많은 영상$}{$CP950=發燒影片/頻道$}{$CP0=Most/Least Viewed$}";
	item1["Category"] = "most";
	item1["type"] = "search";
	item1["Genres"] = "video={$CP949=비디오$}{$CP950=發燒影片$}{$CP0=video$},channel={$CP949=채널$}{$CP950=頻道$}{$CP0=channel$}";
	ret.insertLast(item1);

	return ret;
}

string GetStringValue(string param, string key)
{
	int p = param.find(key + "=");

	if (p >= 0)
	{
		p += key.length() + 1;

		int e = param.find(",", p + 1);		
		if (e < p) e = param.length();
		return param.substr(p, e - p);
	}
	return "";
}

string GetSorts(string Category, string Extra, string PathToken, string Query)
{
	string sorts;
	string type = GetStringValue(Extra, "genre");
	
	if (!Query.empty() || type == "channel")
	{
		sorts = "relevance={$CP949=연관순$}{$CP950=依關聯性$}{$CP0=by relevance$}";
		sorts += ",date={$CP949=날짜순$}{$CP950=依上傳日期$}{$CP0=by date$}";
		sorts += ",rating={$CP949=평점순$}{$CP950=依評分$}{$CP0=by rating$}";
		sorts += ",title={$CP949=제목순$}{$CP950=依標題$}{$CP0=by title$}";
		sorts += ",videoCount={$CP949=비디오 갯수순$}{$CP950=依影片數量$}{$CP0=by video count$}";
		sorts += ",viewCount={$CP949=시청순$}{$CP950=依觀看次數$}{$CP0=by view count$}";
	}
	return sorts;
}

bool AssignMetaData(dictionary &item, JsonValue &in snippet)
{
	bool IsDel = false;
	
	JsonValue title = snippet["title"];
	if (title.isString())
	{
		string str = title.asString();

		item["title"] = str;
		IsDel = "Deleted video" == str;
	}

	JsonValue channelTitle = snippet["channelTitle"];
	if (channelTitle.isString())
	{
		string str = channelTitle.asString();

		item["author"] = str;
	}

	JsonValue description = snippet["description"];
	if (description.isString())
	{
		string str = description.asString();

		item["desc"] = str;
	}

	JsonValue publishedAt = snippet["publishedAt"];
	if (publishedAt.isString())
	{
		string str = publishedAt.asString();

		item["date"] = str;
	}
	
	JsonValue thumbnails = snippet["thumbnails"];
	if (thumbnails.isObject())
	{
		JsonValue medium = thumbnails["medium"];
		string thumbnail;

		if (medium.isObject())
		{
			JsonValue url = medium["url"];

			if (url.isString()) thumbnail = url.asString();
		}
		if (thumbnail.empty())
		{
			JsonValue def = thumbnails["default"];

			if (def.isObject())
			{
				JsonValue url = def["url"];

				if (url.isString()) thumbnail = url.asString();
			}
		}
		/*
		JsonValue high = thumbnails["high"];
		if (high.isObject())
		{
			JsonValue url = high["url"];

			if (url.isString()) thumbnail = url.asString();
		}*/
		if (!thumbnail.empty()) item["thumbnail"] = thumbnail;
	}
	else if (IsDel) return false;
	return true;
}

array<dictionary> GetUrlList(string Category, string Extra, string PathToken, string Query, string PageToken)
{
	array<dictionary> ret;
	string type = GetStringValue(Extra, "genre");
	string video = "video";
	string channel = "channel";
	string api;
	
	if (type.empty()) type = video;
	if (Query.empty() && type == video)
	{
		string ctry = HostIso3166CtryName();

		api = "https://www.googleapis.com/youtube/v3/videos?part=snippet&chart=mostPopular&maxResults=50&regionCode=" + ctry;
	}	
	else
	{
		string add;

		if (type == channel && !PathToken.empty())
		{
			if (PageToken.empty())
			{
				dictionary item;
			
				item["title"] = "..";
				item["folder"] = "parent";
				ret.insertLast(item);
			}
			type = video;
			add = PathToken;
		}
		api = "https://www.googleapis.com/youtube/v3/search?part=snippet&maxResults=50&type=" + type + "&q=" + HostUrlEncode(Query);
		if (!Extra.empty())
		{
			string order = GetStringValue(Extra, "sort");

			if (!order.empty()) api += "&order=" + order;
		}
		if (!add.empty()) api += "&channelId=" + add;
		if (Query.empty())
		{
			string ctry = HostIso3166CtryName();

			api += "&regionCode=" + ctry;
		}
	}
	if (!PageToken.empty())
	{
		api = api + "&pageToken=" + PageToken;
		PageToken = "";
	}
	string json = HostUrlGetStringGoogle(api);
	JsonReader Reader;
	JsonValue Root;
	if (Reader.parse(json, Root) && Root.isObject())
	{
		JsonValue items = Root["items"];

		if (items.isArray())
		{
			JsonValue nextPageToken = Root["nextPageToken"];
			if (nextPageToken.isString()) PageToken = nextPageToken.asString();

			for (int i = 0, len = items.size(); i < len; i++)
			{
				JsonValue item = items[i];

				if (item.isObject())
				{
					JsonValue id = item["id"];

					if (id.isString() || id.isObject())
					{
						JsonValue snippet = item["snippet"];

						if (snippet.isObject())
						{
							if (type == channel)
							{
								string cid;

								if (id.isString()) cid = id.asString();
								else if (id.isObject())
								{
									JsonValue videoId = id["channelId"];

									if (videoId.isString()) cid = videoId.asString();
								}
								if (!cid.empty())
								{
									dictionary item;
									
									item["url"] = "https://www.youtube.com/channel/" + cid;

									if (!AssignMetaData(item, snippet)) continue;
									item["folder"] = "1";
									item["PathToken"] = cid;
									ret.insertLast(item);
								}
							}
							else
							{						
								string vid;

								if (id.isString()) vid = id.asString();
								else if (id.isObject())
								{
									JsonValue videoId = id["videoId"];

									if (videoId.isString()) vid = videoId.asString();
								}
								if (!vid.empty())
								{
									dictionary item;

									item["url"] = "http://www.youtube.com/watch?v=" + vid;

									if (!PageToken.empty())
									{
										item["PageToken"] = PageToken;
										PageToken = "";
									}
									
									if (!AssignMetaData(item, snippet)) continue;
									ret.insertLast(item);
								}
							}
						}
					}
				}
			}
		}
	}
	return ret;
}
