/*
	subtitle search by subDB
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

string GetHash(string FileName)
{
	string hash = "";
	uint64 fp = HostFileOpen(FileName);

	if (fp != 0)
	{
		int64 size = HostFileLength(fp);
		string buf1 = HostFileRead(fp, 64 * 1024);
		
//		HostFileSeek(fp, size - 64 * 1024, 0);
		HostFileSeek(fp, - 64 * 1024, 2);
		string buf2 = HostFileRead(fp, 64 * 1024);
		
		if (!buf1.empty() && !buf2.empty()) hash = HostHashMD5(buf1 + buf2);
		HostFileClose(fp);
	}
	return hash;
}

string UserAgent = "SubDB/1.0 (MPC-HC/1.7.11; https://mpc-hc.org/)";
string API_URL = "http://api.thesubdb.com";

string GetTitle()
{
	return "SubDB";
}

string GetVersion()
{
	return "1";
}

string GetDesc()
{
	return "http://api.thesubdb.com";
}

string GetLanguages()
{
	string url = API_URL + "/?action=languages";
	
	return HostUrlGetString(url, UserAgent);
}

string ServerCheck(string User, string Pass)
{
	string lang = GetLanguages();
	
	if (lang.empty()) return "failed";
	else return "200 OK";
}

array<dictionary> SubtitleSearch(string MovieFileName, dictionary MovieMetaData)
{
	array<dictionary> ret;
	string hash = GetHash(MovieFileName);
	string url = API_URL + "/?action=search&hash=" + hash;
	string text = HostUrlGetString(url, UserAgent);
	
	if (!text.empty())
	{
		string MovieName = string(MovieMetaData["title"]);
		array<string> langs = text.split(",");
		
		for (int i = 0, len = langs.size(); i < len; i++)
		{
			string lang = langs[i];
			
			if (!lang.empty())
			{
				dictionary item;

				item["id"] = "hash=" + hash + "&language=" + lang;
				item["title"] = MovieName + "*";
				item["lang"] = lang;
				
				ret.insertLast(item);
			}
		}
	}	
	return ret;
}

string SubtitleDownload(string id)
{
	string url = API_URL  + "/?action=download&" + id;
	
	return HostUrlGetString(url, UserAgent);
}

string GetUploadFormat()
{
	return "srt";
}

string SubtitleUpload(string MovieFileName, dictionary MovieMetaData, string SubtitleName, string SubtitleContent)
{
//	HostOpenConsole();	-- for debug
	string hash = GetHash(MovieFileName);
	string url = API_URL + "/?action=upload&hash=" + hash;
	string MULTIPART_BOUNDARY = "xYzZY";
	string header = "Content-Type: multipart/form-data; boundary=" + MULTIPART_BOUNDARY + "\r\n";
	string post = "--" + MULTIPART_BOUNDARY + "\r\nContent-Disposition: form-data; name=\"hash\"\r\n\r\n" + hash + "\r\n";
	
	post = post + "--" + MULTIPART_BOUNDARY + "\r\nContent-Disposition: form-data; name=\"file\"; filename=\"" + hash + ".srt\"\r\nContent-Type: application/octet-stream\r\nContent-Transfer-Encoding: binary\r\n\r\n";
	post = post + SubtitleContent;
	post = post + "\r\n--" + MULTIPART_BOUNDARY + "--\r\n";

	uint64 http = HostOpenHTTP(url, UserAgent, header, post);
	if (http != 0)
	{
		string content = HostGetContentHTTP(http);
		// string head = HostGetHeaderHTTP(http);
		int status = HostGetStatusHTTP(http);
		
		HostCloseHTTP(http);
		
		if (content.empty()) content = formatInt(status);
		if (status != 200)
		if (status == 201) return "200 OK";
		else if (status == 403) "already exist";
		else if (status == 400) return "bad request(" + content + ")";
		else if (status == 415) return "unsupported subtitle format(" + content + ")";
		
		return "unknown error(" + status + ")" + " " + content;
	}	
	return "unknown error";
}
