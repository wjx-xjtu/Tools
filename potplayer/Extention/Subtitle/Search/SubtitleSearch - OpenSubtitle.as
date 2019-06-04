/*
	subtitle search by opensubtitle
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

string Token = "";
string ISDB_URL = "http://www.opensubtitles.org/isdb/";
string RPC_URL = "http://api.opensubtitles.org/xml-rpc";

array<dictionary> OldSubtitleSearch(string MovieFileName, dictionary MovieMetaData)
{
	array<dictionary> ret;
	string url = ISDB_URL + "index.php?player=mpc&";
	int64 size = 0;
	uint64 hash = GetHash(MovieFileName, size);
	string title = string(MovieMetaData["title"]);
	string param = "name[0]=" + HostUrlEncode(title) + "&hash[0]=" + formatUInt(hash, "0h", 16) + "&size[0]=" + formatUInt(size, "0h", 16);
	
	url = url + param;
	string text = HostUrlGetString(url, "MPC-HC");
	if (!text.empty())
	{
		string ticket = "";
		string movie = "";
		string subtitle = "";
		string name = "";
		string language = "";
		string iso639_2 = "";
		string format = "";
		string discs = "";
		string disc_no = "";
		string nick = "";
		string email = "";
		array<string> lines = text.split("\n");
		
		for (int i = 0, len = lines.size(); i < len; i++)
		{
			string line = lines[i];
			
			if (!line.empty())
			{
				int s = line.find("=");
				
				if (s > 0)
				{
					string key = line.substr(0, s);
					string value = line.substr(s + 1);
				
					if (key == "ticket") ticket = value;
					else if (key == "movie")
					{
						array<string> movies = text.split("|");
						
						for (int j = 0, len = movies.size(); j < len; j++)
						{
							string m = movies[j];
							
							if (!m.empty())
							{
								if (movie.empty()) movie = m;
								else movie = movie + " ," + m;
							}
						}
					}
					else if (key == "subtitle") subtitle = value;
					else if (key == "name") name = value;
					else if (key == "discs") discs = value;
					else if (key == "disc_no") disc_no = value;
					else if (key == "format") format = value;
					else if (key == "iso639_2") iso639_2 = value;
					else if (key == "language") language = value;
					else if (key == "nick") nick = value;
					else if (key == "email") email = value;
				}
				
				bool IsAdd = false;
				if (line == "endsubtitle") IsAdd = true;
				else if (line == "endmovie") IsAdd = true;
				else if (line == "end")
				{
					IsAdd = true;
					break;
				}
				if (IsAdd && !subtitle.empty() && !movie.empty())
				{
					dictionary item;					
					string id = "id=" + subtitle + "&ticket=";
				
//					id = id + ticket;
					item["id"] = id;
					item["title"] = movie;
					if (!name.empty()) item["fileName"] = name;
					if (!format.empty()) item["format"] = format;
					if (!language.empty()) item["language"] = language;
					if (!iso639_2.empty()) item["lang"] = iso639_2;
					if (!discs.empty() && !disc_no.empty()) item["disc"] = disc_no + "/" + discs;
					if (!nick.empty()) item["nick"] = nick;
					if (!email.empty()) item["email"] = email;
								
					subtitle = "";
					name = "";
					language = "";
					iso639_2 = "";
					disc_no = "";
					discs = "";
					nick = "";
					email = "";
					
					ret.insertLast(item);
				}
			}
		}
	}
	
	return ret;
}

string OldSubtitleDownload(string id)
{
	string url = ISDB_URL + "dl.php?" + id;
	string text = HostUrlGetString(url, "MPC-HC");
	
	return text;
}

array<dictionary> NewSubtitleSearch(string MovieFileName, dictionary MovieMetaData)
{
	array<dictionary> ret;
	int64 size = 0;
	uint64 hash = GetHash(MovieFileName, size);
	string title = string(MovieMetaData["title"]);
	XmlRpcClient xmlrpc(RPC_URL);
	XmlRpcValue args, res;
	
	args[0] = Token;
	args[1][0]["sublanguageid"] = "all";
	if (hash > 0) args[1][0]["moviehash"] = formatUInt(hash, "0h", 16);
	if (size > 0) args[1][0]["moviebytesize"] = formatInt(size);
	if (hash <= 0 && size <= 0 && !title.empty()) args[1][0]["query"] = title;
	args[2]["limit"] = 500;
    if (xmlrpc.execute("SearchSubtitles", args, res) && res.isObject())
	{
		XmlRpcValue data = res["data"];

		if (data.isArray())
		{
			for(int i = 0, len = data.size(); i < len; i++)
			{
				XmlRpcValue v = data[i];
				
				if (v.isObject())
				{
					XmlRpcValue MovieName = v["MovieName"];
					XmlRpcValue IDSubtitleFile = v["IDSubtitleFile"];
				
					if (MovieName.canString() && IDSubtitleFile.canString())
					{
						dictionary item;
					
						XmlRpcValue MovieYear = v["MovieYear"];
						if (MovieYear.canString()) item["year"] = MovieYear.asString();
					
						item["id"] = IDSubtitleFile.asString();
						item["title"] = MovieName.asString();
					
						XmlRpcValue SubFileName = v["SubFileName"];
						if (SubFileName.canString()) item["fileName"] = SubFileName.asString();
					
						XmlRpcValue SubFormat = v["SubFormat"];
						if (SubFormat.isString()) item["format"] = SubFormat.asString();
					
						XmlRpcValue LanguageName = v["LanguageName"];
						if (LanguageName.isString()) item["language"] = LanguageName.asString();
					
						XmlRpcValue ISO639 = v["ISO639"];
						if (ISO639.isString()) item["lang"] = ISO639.asString();
					
						XmlRpcValue SubSumCD = v["SubSumCD"];
						XmlRpcValue SubActualCD = v["SubActualCD"];
						if (SubSumCD.canString() && SubActualCD.canString()) item["disc"] = SubActualCD.asString() + "/" + SubSumCD.asString();
					
						XmlRpcValue SubDownloadsCnt = v["SubDownloadsCnt"];
						if (SubDownloadsCnt.canString()) item["downloadCount"] = SubDownloadsCnt.asString();
					
						XmlRpcValue SeriesSeason = v["SeriesSeason"];
						if (SeriesSeason.canString()) item["seasonNumber"] = SeriesSeason.asString();
					
						XmlRpcValue SeriesEpisode = v["SeriesEpisode"];
						if (SeriesEpisode.canString()) item["episodeNumber"] = SeriesEpisode.asString();
					
						XmlRpcValue SubtitlesLink = v["SubtitlesLink"];
						if (SubtitlesLink.canString()) item["url"] = SubtitlesLink.asString();
					
						XmlRpcValue IDMovieImdb = v["IDMovieImdb"];
						if (IDMovieImdb.canString()) item["imdb"] = IDMovieImdb.asString();
					
						XmlRpcValue SubBad = v["SubBad"];
						if (SubBad.canString()) item["isBad"] = SubBad.asString();
					
						XmlRpcValue SubHearingImpaired = v["SubHearingImpaired"];
						if (SubHearingImpaired.canString()) item["hearingImpaired"] = SubHearingImpaired.asString();
						
						ret.insertLast(item);
						
					}
				}
			}
		}
	}
	
	return ret;
}

string NewSubtitleDownload(string id)
{
	XmlRpcClient xmlrpc(RPC_URL);
	XmlRpcValue args, res;

	args[0] = Token;
	args[1][0] = id;
    if (xmlrpc.execute("DownloadSubtitles", args, res) && res.isObject())
	{
		XmlRpcValue data = res["data"];
		
		if (data.isArray())
		{
			XmlRpcValue sub = data[0];		
			
			if (sub.isObject())
			{
				XmlRpcValue bsse64 = sub["data"];
				
				if (bsse64.isString()) return HostBase64Dec(bsse64.asString());
			}
		}
	}
	return "";
}

string GetTitle()
{
	return "OpenSubtitles";
}

string GetVersion()
{
	return "1";
}

string GetDesc()
{
	return "https://api.opensubtitles.org";
}

string GetLanguages()
{
	string ret = "";
	XmlRpcClient xmlrpc(RPC_URL);
	XmlRpcValue args, res;	
	
	args = "en";
    if (xmlrpc.execute("GetSubLanguages", args, res) && res.isObject())
	{
		XmlRpcValue data = res["data"];
		
		if (data.isArray())
		{
			for(int i = 0, len = data.size(); i < len; i++)
			{
				XmlRpcValue lang = data[i];
				
				if (lang.isObject())
				{
					//XmlRpcValue SubLanguageID = lang["SubLanguageID"];
					XmlRpcValue ISO639 = lang["ISO639"];
					
					if (ISO639.canString())
					{
						string iso = ISO639.asString();
						
						if (!iso.empty())
						{
							if (ret.empty()) ret = iso;
							else ret = ret + "," + iso;
						}
					}
				}
			}
		}
	}
	return ret;
}

string GetLoginTitle()
{
	return "";
}

string GetLoginDesc()
{
	return "";;
}

string ServerCheck(string User, string Pass)
{
//	new
	string result = ServerLogin(User, Pass);
	if (!result.empty() && !Token.empty()) return result;

// old
	string url = ISDB_URL + "test.php";
	string text = HostUrlGetString(url);
	string ret = "200 OK";
	if (text != "ISDb v1")
	{
		int s = text.find("ISDb v");
		
		if (s == 0) ret = "Invalid version";
		else ret = text;
	}
	return ret;
}

string ServerLogin(string User, string Pass)
{
	string ret = "";
	XmlRpcClient xmlrpc(RPC_URL);
	XmlRpcValue args, res;
	
	args[0] = User;
	args[1] = Pass;
	args[2] = "en";
	args[3] = "MPC-HC v1.7.13";
	if (xmlrpc.execute("LogIn", args, res) && res.isObject())
	{
		XmlRpcValue token = res["token"];
		XmlRpcValue status = res["status"];
		
		if (token.canString())
		{
			ServerLogout();
			Token = token.asString();
		}
		if (status.canString()) return status.asString();
	}
	return "cannot connect";
}

void ServerLogout()
{
	if (!Token.empty())
	{
		XmlRpcClient xmlrpc(RPC_URL);
		XmlRpcValue args, res;
		
		args[0] = Token;
		xmlrpc.execute("LogOut", args, res);
		Token = "";
	}
}

string SubtitleWebSearch(string MovieFileName, dictionary MovieMetaData)
{
	string url = ISDB_URL + "index.php?";
	int64 size = 0;
	uint64 hash = GetHash(MovieFileName, size);
	string title = string(MovieMetaData["title"]);
	string param = "name[0]=" + HostUrlEncode(title) + "&hash[0]=" + formatUInt(hash, "0h", 16) + "&size[0]=" + formatUInt(size, "0h", 16);
	
	return url + param;
}

array<dictionary> SubtitleSearch(string MovieFileName, dictionary MovieMetaData)
{
	if (Token.empty()) return OldSubtitleSearch(MovieFileName, MovieMetaData);
	return NewSubtitleSearch(MovieFileName, MovieMetaData);
}

string SubtitleDownload(string id)
{
	if (Token.empty()) return OldSubtitleDownload(id);
	return NewSubtitleDownload(id);
}

string GetUploadFormat()
{
	return "srt";
}


string SubtitleUpload(string MovieFileName, dictionary MovieMetaData, string SubtitleName, string SubtitleContent)
{
	if (!Token.empty())
	{
		int64 size = 0;
		uint64 hash = GetHash(MovieFileName, size);
		string MovieName = string(MovieMetaData["title"]);
		XmlRpcClient xmlrpc(RPC_URL);
		XmlRpcValue args, result;
		string hashStr = formatUInt(hash, "0h", 16);
		
		args[0] = Token;
		args[1]["cd1"]["moviehash"] = hashStr;
		args[1]["cd1"]["moviebytesize"] = formatUInt(size);
		args[1]["cd1"]["subhash"] = HostHashMD5(SubtitleContent);
		args[1]["cd1"]["subfilename"] = SubtitleName;
		args[1]["cd1"]["moviefilename"] = MovieName;	
		if (xmlrpc.execute("TryUploadSubtitles", args, result) && result.isObject())
		{
			XmlRpcValue alreadyindb = result["alreadyindb"];
			
			if (alreadyindb.isBool() && alreadyindb.asBool()) return "already exist";
			else if (alreadyindb.isInt() && alreadyindb.asInt() != 0) return "already exist";
			else
			{
				string imdb = "";
				XmlRpcValue data = result["data"];
				
				if (data.isArray())
				{
					XmlRpcValue data0 = data[0];
					
					if (data0.isObject())
					{
						XmlRpcValue IDMovieImdb = data0["IDMovieImdb"];
						
						if (IDMovieImdb.canString()) imdb = IDMovieImdb.asString();
					}
				}
				
				if (imdb.empty()) // get imdb by CheckMovieHash
				{
					XmlRpcValue _args, _result;
					
					_args[0] = Token;
					_args[1][0] = hashStr;
					if (xmlrpc.execute("CheckMovieHash", _args, _result) && _result.isObject())
					{
						XmlRpcValue data2 = _result["data"];
						
						if (data2.isObject())
						{
							XmlRpcValue moviehash = data2[hashStr];
							
							if (moviehash.isObject())
							{							
								XmlRpcValue ServerName = moviehash["MovieName"];
								
								if (ServerName.isString())
								{
									if (HostCompareMovieName(MovieName, ServerName.asString()))
									{
										XmlRpcValue IDMovieImdb = moviehash["IDMovieImdb"];
										
										if (IDMovieImdb.canString()) imdb = IDMovieImdb.asString();
									}
								}
							}
						}
					}
				}

				if (imdb.empty()) // get imdb by CheckMovieHash2
				{
					XmlRpcValue _args, _result;
					
					_args[0] = Token;
					_args[1][0] = hashStr;
					if (xmlrpc.execute("CheckMovieHash2", _args, _result) && _result.isObject())
					{
						XmlRpcValue data2 = _result["data"];
						
						if (data2.isObject())
						{
							XmlRpcValue moviehash = data2[hashStr];
							
							if (moviehash.isArray())
							{
								for(int i = 0, len = moviehash.size(); i < len; i++)
								{
									XmlRpcValue v = moviehash[i];
									
									if (v.isObject())
									{
										XmlRpcValue ServerName = v["MovieName"];
										
										if (ServerName.isString())
										{
											if (HostCompareMovieName(MovieName, ServerName.asString()))
											{
												XmlRpcValue IDMovieImdb = moviehash["IDMovieImdb"];
												
												if (IDMovieImdb.canString())
												{
													imdb = IDMovieImdb.asString();
													break;
												}
											}
										}
									}
								}
							}
						}
					}
				}

				if (imdb.empty()) // get imdb by SearchMoviesOnIMDB
				{
					XmlRpcValue _args, _result;

					_args[0] = Token;
					_args[1] = MovieName;
					if (xmlrpc.execute("SearchMoviesOnIMDB", _args, _result) && _result.isObject())
					{
						XmlRpcValue data2 = _result["data"];
						
						if (data2.isArray())
						{
							for(int i = 0, len = data2.size(); i < len; i++)
							{
								XmlRpcValue v = data2[i];
								
								if (v.isObject())
								{						
									XmlRpcValue title = v["title"];
									
									if (title.isString())
									{
										if (HostCompareMovieName(MovieName, title.asString()))
										{
											XmlRpcValue id = v["id"];
											
											if (id.canString())
											{
												imdb = id.asString();
												break;
											}
										}
									}
								}
							}
						}
					}
				}
				
				if (!imdb.empty()) // if imdb is exist
				{
					XmlRpcValue _args, _result;
				
					_args[0] = Token;
					_args[1][0]["moviehash"] = hashStr;
					_args[1][0]["moviebytesize"] = size;
					_args[1][0]["imdbid"] = imdb;
					_args[1][0]["subfilename"] = SubtitleName;
					_args[1][0]["moviefilename"] = MovieName;
					if (xmlrpc.execute("InsertMovieHash", _args, _result) && _result.isObject())
					{
						string gzip = HostBase64Enc(HostGzipCompress(SubtitleContent));
						
						args[1]["cd1"]["subcontent"] = gzip;
						args[1]["baseinfo"]["idmovieimdb"] = imdb;
						if (xmlrpc.execute("UploadSubtitles", args, result) && result.isObject())
						{
							XmlRpcValue status = result["status"];

							if (status.isString()) return status.asString();
							return "upload subtitle fail";
						}
						return "upload subtitle error";
					}
					return "insert movie hash error";
				}
				return "cannot find imdb";
			}
			// return "try upload fail";
		}
		return "try upload error";
	}
	return "not login";
}

