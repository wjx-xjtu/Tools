/*
	subtitle search by ysub
*/

//	string GetTitle() 													-> get title for UI
//	string GetVersion													-> get version for manage
//	string GetDesc()													-> get detail information
//	string GetLoginTitle()												-> get title for login dialog
//	string GetLoginDesc()												-> get desc for login dialog
//	string ServerCheck(string User, string Pass) 						-> server check
//	string ServerLogin(string User, string Pass) 						-> login
//	void ServerLogout() 												-> logout
//	string GetLanguages()																-> get support language
//	string SubtitleWebSearch(string MovieFileName, dictionary MovieMetaData)			-> search subtitle bu web browser
//	array<dictionary> SubtitleSearch(string MovieFileName, dictionary MovieMetaData)	-> search subtitle
//	string SubtitleDownload(string id)													-> download subtitle
//	string GetUploadFormat()															-> upload format
//	string SubtitleUpload(string MovieFileName, dictionary MovieMetaData, string SubtitleName, string SubtitleContent)	-> upload subtitle


array<array<string>> LangTable = 
{
    { "sq", "albanian" },
	{ "ar", "arabic" },
	{ "bn", "bengali" },
    { "pb", "brazilian-portuguese" },
	{ "bg", "bulgarian" },
	{ "zh", "chinese" },
    { "hr", "croatian" },
	{ "cs", "czech" },
	{ "da", "danish" },
    { "nl", "dutch" },
	{ "en", "english" },
	{ "fa", "farsi-persian" },
    { "fi", "finnish" },
	{ "fr", "french" },
	{ "de", "german" },
    { "el", "greek" },
	{ "he", "hebrew" },
	{ "hu", "hungarian" },
    { "id", "indonesian" },
	{ "it", "italian" },
	{ "ja", "japanese" },
    { "ko", "korean" },
	{ "lt", "lithuanian" },
	{ "mk", "macedonian" },
    { "ms", "malay" },
	{ "no", "norwegian" },
	{ "pl", "polish" },
    { "pt", "portuguese" },
	{ "ro", "romanian" },
	{ "ru", "russian" },
    { "sr", "serbian" },
	{ "sl", "slovenian" },
	{ "es", "spanish" },
    { "sv", "swedish" },
	{ "th", "thai" },
	{ "tr", "turkish" },
    { "ur", "urdu" },
	{ "vi", "vietnamese" }
};

string GetTitle()
{
	return "ysub";
}

string GetVersion()
{
	return "1";
}

string GetDesc()
{
	return "http://www.yifysubtitles.com";
}

string GetLanguages()
{
	string ret = "";
	
	for (int i = 0, len = LangTable.size(); i < len; i++)
	{
		if (ret.empty()) ret = LangTable[i][0];
		else ret = ret + "," + LangTable[i][0];
	}
	return ret;
}

string ServerCheck(string User, string Pass)
{
	string ret = HostUrlGetString(GetDesc());
	
	if (ret.empty()) return "fail";
	return "200 OK";
}

void AssignItem(dictionary &dst, JsonValue &in src, string dst_key, string src_key = "")
{
	if (src_key.empty()) src_key = dst_key;
	if (src[src_key].isString()) dst[dst_key] = src[src_key].asString();
	else if (src[src_key].isInt64()) dst[dst_key] = src[src_key].asInt64();	
}

array<dictionary> SubtitleSearch(string MovieFileName, dictionary MovieMetaData)
{
	array<dictionary> ret;
	string title = string(MovieMetaData["title"]);
	string api = "https://yts.am/api/v2/list_movies.json?query_term=" + title;
	string json = HostUrlGetString(api);
	JsonReader Reader;
	JsonValue Root;
	
	if (Reader.parse(json, Root) && Root.isObject())
	{
		JsonValue data = Root["data"];
		
		if (data.isObject())
		{			
			JsonValue movies = data["movies"];
			
			if (movies.isArray())
			{
				dictionary imdbs;
				
				for (int i = 0, len = movies.size(); i < len; i++)
				{
					JsonValue movie = movies[i];
					
					if (movie.isObject())
					{
						JsonValue imdb_code = movie["imdb_code"];
						
						if (imdb_code.isString())
						{
							string imdb = imdb_code.asString();

							if (!imdbs.exists(imdb))
							{
								imdbs[imdb] = 1;
								
								api = "http://api.ysubs.com/subs/" + imdb;
								json = HostUrlGetString(api);
								JsonReader Reader2;
								JsonValue Root2;
								if (Reader2.parse(json, Root) && Root2.isObject())
								{
									JsonValue subs = Root2["subs"];
									
									if (subs.isObject())
									{
										JsonValue sub = subs[imdb];
										
										if (sub.isObject())
										{
											array<string> langs = sub.getKeys();
										
											for (int j = 0, len = langs.size(); j < len; j++)
											{
												string lang = langs[j];
												JsonValue it = sub[lang];
												
												if (it.isObject())
												{
													JsonValue url = it["url"];
													
													if (url.isString())
													{													
														dictionary item;
							
														item["id"] = url.asString();
														AssignItem(item, it, "title");
														AssignItem(item, it, "year");
														item["lang"] = lang;
														item["url"] = "http://www.yifysubtitles.com/movie-imdb/" + imdb;
														AssignItem(item, it, "hearingImpaired", "hi");
														
														// local rating = it["rating"]
														// item["isBad"] = 														
														
														ret.insertLast(item);
													}
												}
											}
										}
									}
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

string SubtitleDownload(string download)
{
	string api = "http://www.yifysubtitles.com" + download;
	
	return HostUrlGetString(api);
}
