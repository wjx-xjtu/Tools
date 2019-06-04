/*
	subtitle search by podnapisi
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
 
uint64 GetHash(string FileName)
{
	int64 size = 0;
	uint64 hash = 0;
	uint64 fp = HostFileOpen(FileName);

	if (fp != 0)
	{
		size = HostFileLength(fp);
		hash = size;
		
		for (int i = 0; i < 65536 / 8; i++) hash = hash + HostFileReadQWORD(fp);
		
		int64 ep = size - 65536;
		if (ep < 0) ep = 0;
		HostFileSeek(fp, ep, 0);
		for (int i = 0; i < 65536 / 8; i++) hash = hash + HostFileReadQWORD(fp);
		
		HostFileClose(fp);
	}
	
	return hash;
}

string HtmlSpecialCharsDecode(string str)
{
	str.replace("&amp;", "&");
	str.replace("&quot;", "\"");
	str.replace("&#039;", "'");
	str.replace("&lt;", "<");
	str.replace("&gt;", ">");
	str.replace("&rsquo;", "'");
	
	return str;
}

string API_URL = "https://www.podnapisi.net";

array<array<string>> LangTable =
{
	{ "sl", "Slovenian" },
	{ "en", "English" },                
	{ "no", "Norwegian" },              
	{ "ko", "Korean" },                 
	{ "de", "German" },                 
	{ "is", "Icelandic" },              
	{ "cs", "Czech" },                  
	{ "fr", "French" },                 
	{ "it", "Italian" },                
	{ "bs", "Bosnian" },                
	{ "ja", "Japanese" },               
	{ "ar", "Arabic" },                 
	{ "ro", "Romanian" },               
	{ "es", "Argentino" },              
	{ "hu", "Hungarian" },              
	{ "el", "Greek" },                  
	{ "zh", "Chinese" },                
	{ "",   "" },                       
	{ "lt", "Lithuanian" },             
	{ "et", "Estonian" },               
	{ "lv", "Latvian" },                
	{ "he", "Hebrew" },                 
	{ "nl", "Dutch" },                  
	{ "da", "Danish" },                 
	{ "sv", "Swedish" },                
	{ "pl", "Polish" },                 
	{ "ru", "Russian" },                
	{ "es", "Spanish" },                
	{ "sq", "Albanian" },               
	{ "tr", "Turkish" },                
	{ "fi", "Finnish" },                
	{ "pt", "Portuguese" },             
	{ "bg", "Bulgarian" },              
	{ "",   "" },                       
	{ "mk", "Macedonian" },             
	{ "sr", "Serbian" },                
	{ "sk", "Slovak" },                 
	{ "hr", "Croatian" },               
	{ "",   "" },                       
	{ "zh", "Mandarin" },               
	{ "",   "" },                       
	{ "hi", "Hindi" },                  
	{ "",   "" },                       
	{ "th", "Thai" },                   
	{ "",   "" },                       
	{ "uk", "Ukrainian" },              
	{ "sr", "Serbian (Cyrillic)" },     
	{ "pb", "Brazilian" },              
	{ "ga", "Irish" },                  
	{ "be", "Belarus" },                
	{ "vi", "Vietnamese" },             
	{ "fa", "Farsi" },                  
	{ "ca", "Catalan" },                
	{ "id", "Indonesian" },             
	{ "ms", "Malay" },                  
	{ "si", "Sinhala" },                
	{ "kl", "Greenlandic" },            
	{ "kk", "Kazakh" },                 
	{ "bn", "Bengali" }                 
};

string GetTitle()
{
	return "podnapisi";
}

string GetVersion()
{
	return "1";
}

string GetDesc()
{
	return API_URL;
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

string SubtitleWebSearch(string MovieFileName, dictionary MovieMetaData)
{
	uint64 hash = GetHash(MovieFileName);
	string title = string(MovieMetaData["title"]);
	string country = string(MovieMetaData["country"]);
	string year = string(MovieMetaData["year"]);
	string seasonNumber = string(MovieMetaData["seasonNumber"]);
	string episodeNumber = string(MovieMetaData["episodeNumber"]);
	
	title.replace("and", "");
	title.replace("%!", "");
	title.replace("%?", "");
	title.replace("%&", "");
	title.replace("%'", "");
	title.replace("%:", "");
	if (!country.empty()) title = title + " " + country;
	
	string api = API_URL + "/ppodnapisi/search?sAKA=1";
	if (!title.empty()) api = api + "&sK=" + HostUrlEncode(title);
	if (!year.empty()) api = api + "&sY=" + year;
	if (!seasonNumber.empty()) api = api + "&sTS=" + seasonNumber;
	if (!episodeNumber.empty()) api = api + "&sTE=" + episodeNumber;
	api = api + "&sMH=" + formatUInt(hash, "0h", 16);

	return api;
}

string GetChildElementText(XMLElement element, string key)
{
	string ret = "";	
	XMLElement childElement = element.FirstChildElement(key);
	
	if (childElement.isValid()) ret = childElement.asString();
	return ret;
}

array<dictionary> SubtitleSearch(string MovieFileName, dictionary MovieMetaData)
{
	array<dictionary> ret;
	uint64 hash = GetHash(MovieFileName);
	int page = 1;
	int pages = 1;
	int results = 0;
	string title = string(MovieMetaData["title"]);
	string country = string(MovieMetaData["country"]);
	string year = string(MovieMetaData["year"]);
	string seasonNumber = string(MovieMetaData["seasonNumber"]);
	string episodeNumber = string(MovieMetaData["episodeNumber"]);
	
	title.replace("and", "");
	title.replace("%!", "");
	title.replace("%?", "");
	title.replace("%&", "");
	title.replace("%'", "");
	title.replace("%:", "");
	if (!country.empty()) title = title + " " + country;
	
	while (page <= pages)
	{
		int oldPage = page;
		string api = API_URL + "/ppodnapisi/search?sXML=1&sAKA=1";
		
		if (!title.empty()) api = api + "&sK=" + HostUrlEncode(title);
		if (!year.empty()) api = api + "&sY=" + year;
		if (!seasonNumber.empty()) api = api + "&sTS=" + seasonNumber;
		if (!episodeNumber.empty()) api = api + "&sTE=" + episodeNumber;
		api = api + "&sMH=" + formatUInt(hash, "0h", 16);
		api = api + "&page=" + formatInt(page);
		
		string xml = HostUrlGetString(api);
		XMLDocument dxml;
		if (dxml.Parse(xml))
		{
			XMLElement rootElmt = dxml.FirstChildElement("results");
			
			if (rootElmt.isValid())
			{
				XMLElement paginationElmt = rootElmt.FirstChildElement("pagination");
				
				if (paginationElmt.isValid())
				{
					page = parseInt(GetChildElementText(paginationElmt, "current"));
					pages = parseInt(GetChildElementText(paginationElmt, "count"));
					results = parseInt(GetChildElementText(paginationElmt, "results"));
				}
				if (page > 1) break;
				
				if (results > 0)
				{
					XMLElement subtitleElmt = rootElmt.FirstChildElement("subtitle");
					
					while (subtitleElmt.isValid())
					{
						string pid = GetChildElementText(subtitleElmt, "pid");
						string title = GetChildElementText(subtitleElmt, "title");

						if (!pid.empty() && !title.empty())
						{
							dictionary item;

							item["id"] = pid;
							item["title"] = HtmlSpecialCharsDecode(title);
							
							string year = GetChildElementText(subtitleElmt, "year");
							if (!year.empty()) item["year"] = year;

							string url = GetChildElementText(subtitleElmt, "url");
							if (!url.empty()) item["url"] = url;

							string format = GetChildElementText(subtitleElmt, "format");
							if (format.empty() || format == "SubRip" || format == "N/A") item["format"] = "srt";
							else item["format"] = format;

							string languageName = GetChildElementText(subtitleElmt, "languageName");
							if (!languageName.empty()) item["language"] = languageName;

							string lang = GetChildElementText(subtitleElmt, "language");
							if (!lang.empty()) item["lang"] = lang;

							int languageId = parseInt(GetChildElementText(subtitleElmt, "languageId"));
							if (languageId >= 0 && languageId < LangTable.size())
							{
								array<string> langs = LangTable[languageId];
								string code = langs[0];
								string name = langs[1];
												
								if (!code.empty())
								{
									item["lang"] = code;
									item["language"] = name;
								}
							}										
										
							string tvSeason = GetChildElementText(subtitleElmt, "tvSeason");
							if (!tvSeason.empty()) item["seasonNumber"] = tvSeason;

							string tvEpisode = GetChildElementText(subtitleElmt, "tvEpisode");
							if (!tvEpisode.empty()) item["episodeNumber"] = tvEpisode;

							string cds = GetChildElementText(subtitleElmt, "cds");
							if (!cds.empty()) item["disc"] = cds;

							string downloads = GetChildElementText(subtitleElmt, "downloads");
							if (!downloads.empty()) item["downloadCount"] = downloads;

							string fps = GetChildElementText(subtitleElmt, "fps");
							if (!fps.empty()) item["fps"] = fps;

							XMLElement releasesElem = subtitleElmt.FirstChildElement("releases");
							if (releasesElem.isValid())
							{
								XMLElement releaseElem = releasesElem.FirstChildElement("release");
								string titles = "";
								
								while (releaseElem.isValid())
								{
									string text = releaseElem.asString();
									
									if (!text.empty())
									{
										if (titles.empty()) titles = text;
										else titles = titles + "," + text;
									}
									releaseElem = releaseElem.NextSiblingElement();
								}
							}
									
							string flags = GetChildElementText(subtitleElmt, "flags");
							if (flags.find("n") >= 0) item["hearingImpaired"] = "1";
							if (flags.find("r") >= 0) item["isBad"] = "1";
							
							ret.insertLast(item);
						}
						subtitleElmt = subtitleElmt.NextSiblingElement();
					}
				}
			}
		}
		page++;
		if (oldPage >= page) break;
	}	
	return ret;
}

string SubtitleDownload(string id)
{
	string api = API_URL + "/subtitles/" + id + "/download";

    return HostUrlGetString(api);
}
