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
 
uint64 GetHash(string FileName, int64 &out size)
{
	uint64 hash = 0;
	uint64 fp = HostFileOpen(FileName);
	
	size = 0;
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

string API_URL = "http://napisy24.pl/";

string GetTitle()
{
	return "Napisy24";
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
	return "pl";
}

string ServerCheck(string User, string Pass)
{
	string ret = HostUrlGetString(API_URL);
	
	if (ret.empty()) return "fail";
	return "200 OK";
}

array<dictionary> SubtitleSearch(string MovieFileName, dictionary MovieMetaData)
{
	array<dictionary> ret;
	int64 size = 0;
	uint64 hash = GetHash(MovieFileName, size);
	string title = string(MovieMetaData["title"]);
	string fileName = string(MovieMetaData["fileName"]);
	string content = "postAction=CheckSub";	

    content = content + "&ua=mpc-hc";
    content = content + "&ap=mpc-hc";
    content = content + "&fh=" + formatUInt(hash, "0h", 16); // %016x
    content = content + "&fs=" + formatInt(size);
    content = content + "&fn=" + fileName;
	
	string api = API_URL + "run/CheckSubAgent.php";
	string data = HostUrlGetString(api, "MPC-HC/1.7.11", "Content-Type: application/x-www-form-urlencoded\r\n", content);
	if (!data.empty())
	{
		string status = data.substr(0, 4);
		
		if (status == "OK-2" || status == "OK-3")
		{
			data.erase(0, 5);
			int infoEnd = data.find("||");
			
			if (infoEnd >= 0)
			{
				dictionary item;
				string fileContents = data.substr(infoEnd + 2);
				
				item["fileContent"] = fileContents;
				item["title"] = title;
				item["lang"] = GetLanguages();
				
				data.erase(infoEnd);
				array<string> infos = data.split("|");
				for (int i = 0, len = infos.size(); i < len; i++)
				{
					string line = infos[i];
					
					if (!line.empty())
					{
						int p = line.find(":");
						
						if (p > 0)
						{
							string left = line.substr(0, p);
							string right = line.substr(p + 1);
						
							if (left == "napisId") item["url"] = API_URL + "komentarze?napisId=" + right;
							else if (left == "ftitle") item["title"] = right;
							else if (left == "fimdb") item["imdb"] = right;
							else if (left == "fyear") item["year"] = right;
							else if (left == "fps") item["fps"] = right;
							else if (left == "time") item["time"] = right;
						}
					}
				}
				ret.insertLast(item);
			}
		}
	}
	
	return ret;
}

string SubtitleDownload(string download)
{
	return download;
}

