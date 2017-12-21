module bak;

import sdlang;
import utils.misc;
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
					if (to!uinteger(processedName[1]) > latestCount){
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
		string latestName = files.length > 0 ? files[0] : "";
		uinteger latestCount = 0;
		foreach(bakFile; files){
			string[3] processedName = readBackupFilename(bakFile);
			if (processedName[0] == fName && processedName[2] == BACKUP_EXTENSION){
				if (processedName[1].isNum){
					// ok, this is a backup
					if (to!uinteger(processedName[1]) > latestCount){
						latestName = bakFile;
						latestCount = to!uinteger(processedName[1]);
					}
				}
			}
		}
		return latestName;
	}

	/// returns true if a file/any-file-in-a-dir was modified after a data/time
	static bool hasModified(string filePath, SysTime backupDate){
		// now check if any file in that dir, or if it is a file, then if it's been modified after backup, then make another
		if (filePath.isDir){
			string path = filePath.dirName~'/';
			// recursion for all the files
			string[] dirFiles = listdir(filePath);
			foreach (file; dirFiles){
				if (hasModified(path~file, backupDate)){
					return true;
				}
			}
			return false;
		}else{
			if (timeLastModified(filePath) > backupDate){
				return true;
			}
			return false;
		}
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
	/// stores whether existing files will be overwritten when writing backups
	private bool storedOverwriteExisting = true;
	/// true if existing files will be overwritten when writing backups
	@property bool overwriteExisitng(){
		return storedOverwriteExisting;
	}
	/// true if existing files will be overwritten when writing backups
	@property bool overwriteExisitng(bool newVal){
		changed = true;
		return storedOverwriteExisting = newVal;
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
			// now for overWriteExisting
			storedOverwriteExisting = rootTag.getTagValue("overwriteExisting", true);
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
		fileVals.length = filePaths.length;
		foreach (i, path; filePaths){
			fileVals[i] = Value(path);
		}
		tags = [
			new Tag(rootTag,"","file", fileVals),
			new Tag(rootTag,"","overwriteExisting",[Value(overwriteExisitng)]),
			new Tag(rootTag,"","backupStartCommand",[Value(backupStartCommand)]),
			new Tag(rootTag,"","backupFinishCommand",[Value(backupFinishCommand)]),
			new Tag(rootTag,"","backupFailCommand",[Value(backupFailCommand)])
		];
		// add them all to the rootTag
		/*foreach (tag; tags){
			rootTag.add(tag);
		}*/
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

/// returns array containing file names in a dir
/// 
/// taken from: https://dlang.org/library/std/file/dir_entries.html
string[] listdir(string pathname){
	import std.algorithm;
	import std.array;
	import std.file;
	import std.path;
	
	return std.file.dirEntries(pathname, SpanMode.shallow)
		.filter!(a => a.isFile)
			.map!(a => std.path.baseName(a.name))
			.array;
}