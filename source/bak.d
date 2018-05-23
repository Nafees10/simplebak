module bak;

import sdlang;
import utils.misc;
import utils.lists;
import std.file;
import std.path;
import std.datetime;
import std.conv : to;

private const BACKUP_EXTENSION = ".tar.gz";

/// struct to make backups
struct BakMan{
	/// reads a filename of a backup file, separating the name, count, and extension.
	/// 
	/// returns [name, count, extension], or ["","",""] if it's not a backup filename
	static string[3] readBackupFilename(string backupFile){
		string[3] r;
		// the ending must be ".tar.gz", and the format is: "F.X.tar.gz"
		if (backupFile.length < BACKUP_EXTENSION.length+2){
			return ["","",""];
		}
		r[2] = backupFile[backupFile.length-BACKUP_EXTENSION.length .. backupFile.length].dup;
		if (r[2] != BACKUP_EXTENSION){
			return ["","",""];
		}
		backupFile.length -= BACKUP_EXTENSION.length;
		// read the count
		foreach_reverse(i, c; backupFile){
			if (c == '.'){
				r[1] = backupFile[i+1 .. backupFile.length];
				break;
			}
		}
		if (r[1].length == 0){
			return ["","",""];
		}
		// remove the count, and its dot
		r[0] = backupFile[0 .. backupFile.length-(r[1].length+1)];
		return r;
	}
	/// returns the date the last backup was done
	static SysTime lastBackupDate(string filePath){
		if (!exists(filePath.dirName~"/backups")){
			return SysTime();
		}
		string backupDir = filePath.dirName~"/backups";
		string fName = baseName(filePath);
		string[] files = listdir(backupDir~'/');
		// they're stored like: bakName.1.tar.gz, bakName.2.tar.gz .. where 2 is newer than 1
		// get latest
		uinteger minNameLength = fName.length+BACKUP_EXTENSION.length+2; // fName.length+".X"+extension
		// the date modified of the latest backup
		SysTime latestDate;
		uinteger latestCount = 0;
		foreach(bakFile; files){
			string[3] processedName = readBackupFilename(bakFile);
			if (processedName[0] == fName && processedName[2] == BACKUP_EXTENSION){
				if (processedName[1].isNum){
					// ok, this is a backup
					if (to!uinteger(processedName[1]) >= latestCount){
						latestDate = timeLastModified(backupDir~'/'~bakFile);
						latestCount = to!uinteger(processedName[1]);
					}
				}
			}
		}
		return latestDate;
	}

	/// returns the relative file path of the latest backups
	static string latestBackup(string filePath){
		if (!exists(filePath.dirName~"/backups")){
			return "";
		}
		string backupDir = filePath.dirName~"/backups";
		string fName = baseName(filePath);
		string[] files = listdir(backupDir~'/');
		// they're stored like: bakName.1.tar.gz, bakName.2.tar.gz .. where 2 is newer than 1
		// get latest
		uinteger minNameLength = fName.length+BACKUP_EXTENSION.length+2; // fName.length+".X"+extension
		// the date modified of the latest backup
		string latestName;
		uinteger latestCount = 0;
		foreach(bakFile; files){
			string[3] processedName = readBackupFilename(bakFile);
			if (processedName[0] == fName && processedName[2] == BACKUP_EXTENSION){
				if (processedName[1].isNum){
					// ok, this is a backup
					if (to!uinteger(processedName[1]) >= latestCount){
						latestName = bakFile;
						latestCount = to!uinteger(processedName[1]);
					}
				}
			}
		}
		return latestName;
	}

	/// makes backup of a file/dir
	/// 
	/// returns true on success, false on failure.
	static bool makeBackup(string filePath){
		import std.process, std.stdio;
		// get the filename of the new backup file
		string bakFilename = latestBackup(filePath);
		// add one to the count of the latest backup, or make new name if none exists
		if (bakFilename.length == 0){
			bakFilename = baseName(filePath)~".0"~BACKUP_EXTENSION;
		}else{
			string[3] processedName = readBackupFilename(bakFilename);
			processedName[1] = to!string(to!uinteger(processedName[1])+1);
			bakFilename = processedName[0] ~ '.' ~ processedName[1] ~ BACKUP_EXTENSION;
		}
		// make the dir if it doesnt exist
		if (!exists(filePath.dirName~"/backups")){
			mkdirRecurse(filePath.dirName~"/backups");
		}
		// now to make the backup
		writeln ("Making backup using:\n","tar -cf '"~filePath.dirName~"/backups/"~bakFilename~"' '"~filePath~"'");
		auto result = executeShell("tar -cf '"~filePath.dirName~"/backups/"~bakFilename~"' '"~filePath~"'");
		// check if successful
		if (result.status == 0){
			// successful
			return true;
		}
		// log it
		writeln ("tar -cf returned: ",result.output);
		return false;
	}
}

/// struct to read config from SDL file
struct ConfigFile{
	/// stores whether the file has been changed in memory after loading
	private bool changed=false;
	/// stores filename of currently open file
	private string filename;
	/// stores the file paths which have to be included in backups
	private string[] storedFilePaths;
	/// array of files to include in backups
	@property string[] filePaths(){
		return storedFilePaths.dup;
	}
	/// array of files to include in backups
	@property string[] filePaths(string[] newVal){
		changed = true;
		storedFilePaths = newVal.dup;
		return newVal;
	}
	/// stores the file paths which are to be excluded from backups
	private string[] storedExclude;
	/// returns: array of filepaths to exclude in backups
	@property string[] excludeList(){
		return storedExclude.dup;
	}
	/// array of filepaths to exclude in backups
	@property string[] excludeList(string[] newList){
		changed = true;
		storedExclude = newList.dup;
		return newList;
	}
	/// stores a shell command to execute before starting to make backup
	private string storedBackupStartCommand;
	/// shell command to execute before backup starts
	@property string backupStartCommand(){
		return storedBackupStartCommand;
	}
	/// shell command to execute before backup starts
	@property string backupStartCommand(string newVal){
		changed = true;
		return storedBackupStartCommand = newVal;
	}
	/// stores a shell command to execute after backing up has finished
	private string storedBackupFinishCommand;
	/// shell command to execute after backup's done
	@property string backupFinishCommand(){
		return storedBackupFinishCommand;
	}
	/// shell command to execute after backup's done
	@property string backupFinishCommand(string newVal){
		changed = true;
		return storedBackupFinishCommand = newVal;
	}
	/// stores the command to execute if backup fails
	private string storedBackupFailCommand;
	/// shell command to execute if backup fails
	@property string backupFailCommand(){
		return storedBackupFailCommand;
	}
	/// shell command to execute if backup fails
	@property string backupFailCommand(string newVal){
		changed = true;
		return storedBackupFailCommand  = newVal;
	}
	/// reads config from a file
	void openConfig(string file){
		import std.variant;
		if (exists(file)){
			Tag rootTag = parseFile(file);
			// read values now
			// first, read filepaths
			Value[] fileTagVals = rootTag.getTagValues("file");
			storedFilePaths.length = fileTagVals.length;
			foreach (i, val; fileTagVals){
				storedFilePaths[i] = *(val.peek!(string));
			}
			// excludeList
			fileTagVals = rootTag.getTagValues("exclude");
			storedExclude.length = fileTagVals.length;
			foreach (i, val; fileTagVals){
				storedExclude[i] = *(val.peek!string);
			}
			// and backupStartCommand
			storedBackupStartCommand = rootTag.getTagValue("backupStartCommand", "");
			// backupFinishCommand
			storedBackupFinishCommand = rootTag.getTagValue("backupFinishCommand", "");
			// backupFailCommand
			storedBackupFailCommand = rootTag.getTagValue("backupFailCommand", "");
			changed = false;
		}else{
			// file didnt exist, to make it, set changed=true
			changed = true;
		}
		// done!
		filename = file;
	}
	/// saves the config file back to disk, whether changed or not
	/// 
	/// `file` is the name of file to write to
	void saveConfig(string file){
		// prepare the tags
		Tag[] tags;
		tags.length = 5;
		Tag rootTag = new Tag();
		Value[] fileVals;
		fileVals.length = storedFilePaths.length;
		foreach (i, path; storedFilePaths){
			fileVals[i] = Value(path);
		}
		Value[] excludeVals;
		excludeVals.length = storedExclude.length;
		foreach (i, path; storedExclude){
			excludeVals[i] = Value(path);
		}
		tags = [
			new Tag(rootTag,"","file", fileVals),
			new Tag(rootTag,"","exclude", excludeVals),
			new Tag(rootTag,"","backupStartCommand",[Value(backupStartCommand)]),
			new Tag(rootTag,"","backupFinishCommand",[Value(backupFinishCommand)]),
			new Tag(rootTag,"","backupFailCommand",[Value(backupFailCommand)])
		];
		// if dir doesnt exist, make it
		if (!dirName(file).exists){
			mkdirRecurse(file.dirName);
		}
		write(file, rootTag.toSDLDocument);
		// destroy all the tags
		.destroy(rootTag);
		foreach (tag; tags){
			.destroy(tag);
		}
	}
	/// saves the config back to same file as was read from, only if changed
	void saveConfig(){
		if (changed){
			saveConfig(filename);
		}
	}
}

/// returns: array containing file paths that were modified after given date
/// 
/// `filePath` is the path to the dir/file to check
/// `lastTime` is the time to check against
/// `exclude` is a lit of files/dirs to not to include in the check
string[] filesModified(string filePath, SysTime lastTime, string[] exclude = []){
	import std.algorithm;
	import std.array;
	
	// make sure the filePath is not in exclude
	if (exclude.indexOf(filePath) >= 0){
		return [];
	}
	if (filePath.isDir){
		LinkedList!string modifiedList = new LinkedList!string;
		FIFOStack!string filesToCheck = new FIFOStack!string;
		filesToCheck.push(listdir(filePath));
		// go through the stack
		while (filesToCheck.count > 0){
			string file = filesToCheck.pop;
			if (!isAbsolute(file)){
				file = absolutePath(filePath~'/'~file);
			}
			if (exclude.indexOf(file) >= 0){
				continue;
			}
			// check if it's a dir, case yes, push it's files too
			if (file.isDir){
				filesToCheck.push(listdir(file));
			}else if (file.isFile){
				// is file, check if it was modified
				if (timeLastModified(file) > lastTime){
					modifiedList.append(absolutePath(file));
				}
			}
		}
		string[] r = modifiedList.toArray;
		.destroy (modifiedList);
		.destroy (filesToCheck);
		return r;
	}else{
		if (timeLastModified(filePath) > lastTime){
			return [filePath];
		}
	}
	return [];
}

/// returns an array containing files/dirs in a dir (pathname)
private string[] listdir(string pathname){
	import std.algorithm;
	import std.array;

	return std.file.dirEntries(pathname, SpanMode.shallow)
		.filter!(a => (a.isFile || a.isDir))
		.map!(a => std.path.absolutePath(a.name))
		.array;
}
