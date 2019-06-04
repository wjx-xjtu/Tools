/*
	real time subtitle translate for PotPlayer using google API
*/

// string GetTitle() 														-> get title for UI
// string GetVersion														-> get version for manage
// string GetDesc()															-> get detail information
// string GetLoginTitle()													-> get title for login dialog
// string GetLoginDesc()													-> get desc for login dialog
// string ServerLogin(string User, string Pass)								-> login
// string ServerLogout()													-> logout
// array<string> GetSrcLangs() 												-> get source language
// array<string> GetDstLangs() 												-> get target language
// string Translate(string Text, string &in SrcLang, string &in DstLang) 	-> do translate !!

string JsonParse(string json)
{
	JsonReader Reader;
	JsonValue Root;
	string ret = "";	
	
	if (Reader.parse(json, Root) && Root.isArray())
	{
		for (int i = 0, len = Root.size(); i < len; i++)
		{
			JsonValue child1 = Root[i];
			
			if (child1.isArray())
			{
				for (int j = 0, len = child1.size(); j < len; j++)
				{		
					JsonValue child2 = child1[j];
					
					if (child2.isArray())
					{
						JsonValue item = child2[0];
				
						if (item.isString()) ret = ret + item.asString();
					}
				}
				break;
			}
		}
	} 
	return ret;
}

string ReplaceHTML(string str)
{
	// replace \x type...
	while (true)
	{
		int s = str.findFirst("\\x");
		
		if (s >= 0)
		{
			string sub = str.substr(s + 2, 2);
			
			if (sub.empty()) break;
			else
			{
				int ch = parseInt(sub, 16);
				
				str[s] = ch;
				str.erase(s + 1, 3);
			}
		}
		else break;
	}
	
	// replace &# type...
	int sp = 0;
	while (true)
	{
		int s = str.findFirst("&#", sp);
		
		if (s >= 0)
		{
			int e = str.findFirst(";", s + 3);
			
			if (e > s)
			{
				string sub = str.substr(s + 2, e - s - 2);
				int ch;
				
				if (sub.substr(0, 1) == "x") ch = parseInt(str.substr(s + 3, e - s - 3), 16);
				else ch = parseInt(sub, 10);
				str[s] = ch;
				str.erase(s + 1, e - s);
				sp = s + 1;
			}
			else break;
		}
		else break;
	}

	str.replace("&amp;", "&");
	str.replace("&quot;", "\"");
	str.replace("&#039;", "\'");
	str.replace("&lt;", "<");
	str.replace("&gt;", ">");
	str.replace("&rsquo;", "'");
	return str;
}

string HtmlParse(string data, string DstLang)
{
	string ret = "";
	string search = "TRANSLATED_TEXT='";
	int s = data.findFirst(search);

	if (s >= 0)
	{
		int e = s + search.length();
		int s2 = data.findFirst("'", e + 1);
	
		if (s2 >= 0) return ReplaceHTML(data.substr(e, s2 - e));
	}
	if (DstLang == "romanji")
	{
		s = data.findFirst("<div id=res-translit");
		if (s >= 0)
		{
			s = data.findFirst(">", s + 1);
			if (s >= 0)
			{
				s = s + 1;
				int s2 = data.findFirst("</div>", s);
				if (s2 >= 0) ret = data.substr(s, s2);
			}
		}
	}
	else
	{
		s = data.findFirst("<span id=result_box");
		if (s >= 0)
		{
			s = data.findFirst("<span title=", s + 1);
			while (s >= 0)
			{
				s = data.findFirst(">", s);
				while (s >= 0 && data.substr(s - 3, 4) == "<br>")
				{
					s = data.findFirst(">", s + 1);
				}
				if (s > 0)
				{
					s = s + 1;
					int s2 = data.findFirst("</span>", s);
					if (s2 > 0) ret = ret + data.substr(s, s2 - s);
					s = data.findFirst("<span title=", s + 1);
				}
			}
		}
	}	
	return ret;
}

array<string> LangTable = 
{
	"af",
	"sq",
	"am",
	"ar",
	"hy",
	"az",
	"eu",
	"be",
	"bn",
	"bh",
	"bs",
	"bg",
	"my",
	"ca",
	"ceb",
// 	"chr",
//	"zh",
	"zh-CN",
	"zh-TW",
	"hr",
	"cs",
	"da",
// 	"dv",
	"nl",
	"en",
	"eo",
	"et",
	"tl",
	"fi",
	"fr",
	"gl",
	"ka",
	"de",
	"el",
// 	"gn",
	"gu",
	"ht",
	"ha",
	"iw",
	"hi",
	"hmn",
	"hu",
	"is",
	"ig",
	"id",
	"ga",
// 	"iu",
	"it",
	"ja",
	"jw",
	"kn",
	"kk",
	"km",
	"ko",
	"ku",
	"ky",
	"lo",
	"la",
	"lv",
	"lt",
	"mk",
	"ms",
	"ml",
	"mt",
	"mi",
	"mr",
	"mn",
	"ne",
	"no",
//	"or",
	"ps",
	"fa",
	"pl",
	"pt",
	"pa",
	"ro",
//	"romanji",
	"ru",
//	"sa",
	"sr",
	"sd",
	"st",
	"si",
	"sk",
	"sl",
	"so",
	"es",
	"sw",
	"sv",
	"sw",
	"tg",
	"ta",
//	"tl",
	"te",
	"th",
//	"bo",
	"tr",
	"uk",
	"ur",
	"uz",
//	"ug",
	"vi",
	"cy",
	"xh",
	"yi",
	"yo",
	"zu"
};

string UserAgent = "Mozilla/5.0 (Windows NT 6.1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/41.0.2228.0 Safari/537.36";

string GetTitle()
{
	return "{$CP949=구글 번역$}{$CP950=Google 翻譯$}{$CP0=Google translate$}";
}

string GetVersion()
{
	return "1";
}

string GetDesc()
{
	return "https://translate.google.com/";
}

string GetLoginTitle()
{
	return "";
}

string GetLoginDesc()
{
	return "";
}

array<string> GetSrcLangs()
{
	array<string> ret = LangTable;
	
	ret.insertAt(0, ""); // empty is auto
	return ret;
}

array<string> GetDstLangs()
{
	array<string> ret = LangTable;
	
	return ret;
}

string Translate(string Text, string &in SrcLang, string &in DstLang)
{
//	HostOpenConsole();	// for debug
	
	if (SrcLang.length() <= 0) SrcLang = "auto";
	
//	API.. Always UTF-8
	string enc = HostUrlEncode(Text);
	string url = "https://translate.googleapis.com/translate_a/single?client=gtx&sl=" + SrcLang + "&tl=" + DstLang + "&dt=t&q=" + enc;
	string text = HostUrlGetString(url, UserAgent);
	string ret = JsonParse(text);
	if (ret.length() > 0)
	{
		SrcLang = "UTF8";
		DstLang = "UTF8";
		return ret;
	}	

//	http content
	url = "https://translate.google.com/?hl=en&eotf=1&sl=" + SrcLang + "&tl=" + DstLang + "&q=" + enc;
	text = HostUrlGetString(url, UserAgent);
	ret = HtmlParse(text, DstLang);
	int p = text.findFirst("UTF-8");
	if (p >= 0)
	{
		SrcLang = "UTF8";
		DstLang = "UTF8";
		return ret;
	}
	return ret;
}
