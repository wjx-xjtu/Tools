/*
	subtitle search by titlovi
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
 

string API_URL = "http://api.titlovi.com/xml_get_api.ashx?";

array<array<string>> LangTable =
{
	{ "hr", "hr" }, 
	{ "sr", "sr" }, 
	{ "rs", "sr" }, 
	{ "si", "sl" }, 
	{ "ba", "bs" }, 
	{ "en", "en" }, 
	{ "mk", "mk" }
};

string GetTitle()
{
	return "titlovi";
}

string GetVersion()
{
	return "1";
}

string GetDesc()
{
	return "https://titlovi.com/";
}

string GetLanguages()
{
	string ret = "";
	
	for(int i = 0, len = LangTable.size(); i < len; i++)
	{
		string lang = LangTable[i][0];
		
		if (!lang.empty())
		{
			if (ret.empty()) ret = lang;
			else ret = ret + "," + lang;
		}
	}
	return ret;
}

string ServerCheck(string User, string Pass)
{
	string ret = HostUrlGetString(API_URL);
	
	if (ret.empty()) return "fail";
	return "200 OK";
}

string g_User;
string g_Pass;

string ServerLogin(string User, string Pass)
{
	g_User = User;
	g_User = Pass;
	if (User.empty() && Pass.empty()) return "need app key";
	return "ok";
}

string GetChildElementText(XMLElement element, string key)
{
	string ret = "";	
	XMLElement childElement = element.FirstChildElement(key);
	
	if (childElement.isValid()) ret = childElement.asString();
	return ret;
}

string GetUserLang()
{
	string user = HostIso639LangName();
	
	for(int i = 0, len = LangTable.size(); i < len; i++)
	{
		string lang = LangTable[i][0];
		
		if (user == lang) return lang;
	}
	return "";
}

array<dictionary> SubtitleSearch(string MovieFileName, dictionary MovieMetaData)
{
	array<dictionary> ret;
	string title = string(MovieMetaData["title"]);
	string country = string(MovieMetaData["country"]);
	string year = string(MovieMetaData["year"]);
	string seasonNumber = string(MovieMetaData["seasonNumber"]);
	string episodeNumber = string(MovieMetaData["episodeNumber"]);
	string api = API_URL;
	string lang = GetUserLang();
	
	if (!g_User.empty()) api = api + "?x-dev_api_id=" + g_User;
	else if (!g_Pass.empty()) api = api + "?x-dev_api_id=" + g_Pass;
	api = api + "&mt=" + (seasonNumber.empty() ? "1" : "2");
	api = api + "keyword=" + HostUrlEncode(title);
	if (!seasonNumber.empty()) api = api + "&season=" + seasonNumber;
	if (!episodeNumber.empty()) api = api + "&episode=" + episodeNumber;
	if (!year.empty()) api = api + "&year=" + year;
	if (!lang.empty()) api = api + "&language=" + lang;
	
	string xml = HostUrlGetString(api);
	XMLDocument dxml;
	if (dxml.Parse(xml))
	{
		XMLElement rootElmt = dxml.FirstChildElement("subtitles");
			
		if (rootElmt.isValid())
		{
			int num = rootElmt.asInt("resultsCount");
			
			if (num > 0)
			{
				XMLElement subtitleElmt = rootElmt.FirstChildElement();
					
				while (subtitleElmt.isValid())
				{
					string title = GetChildElementText(subtitleElmt, "title");
					string url = "";
					string id = "";
					XMLElement subtitleChildElmt = subtitleElmt.FirstChildElement("urls");
					
					if (subtitleChildElmt.isValid())
					{
						XMLElement URLElement = subtitleChildElmt.FirstChildElement("url");
						
						while (URLElement.isValid())
						{
                            if (!URLElement.Attribute("what", "download").empty()) url = URLElement.asString();
                            if (!URLElement.Attribute("what", "direct").empty()) id = URLElement.asString();
                            URLElement = URLElement.NextSiblingElement();						
						}
					}

					if (!title.empty() && !id.empty())
					{
						dictionary item;

						item["title"] = title;
						item["id"] = id;
						if (!url.empty()) item["url"] = url;
						
						string imdbId = GetChildElementText(subtitleElmt, "imdbId");
						if (!imdbId.empty()) item["imdb"] = imdbId;						
							
						string year = GetChildElementText(subtitleElmt, "year");
						if (!year.empty()) item["year"] = year;
						
						string cd = GetChildElementText(subtitleElmt, "cd");
						if (!cd.empty()) item["disc"] = cd;

						string downloads = GetChildElementText(subtitleElmt, "downloads");
						if (!downloads.empty()) item["downloadCount"] = downloads;
						
						XMLElement TVShow = subtitleElmt.FirstChildElement("TVShow");
						if (TVShow.isValid())
						{
							item["seasonNumber"] = GetChildElementText(TVShow, "season");
							item["episodeNumber"] = GetChildElementText(TVShow, "episode");
						}						
						
						ret.insertLast(item);

						subtitleElmt = subtitleElmt.NextSiblingElement();
					}
				}
			}
		}
	}	
	return ret;
}

string SubtitleDownload(string id)
{
	string api = id;

    return HostUrlGetString(api);
}
