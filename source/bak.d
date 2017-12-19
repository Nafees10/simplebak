module bak;

import sdlang;
import utils.misc;
import std.file;
import std.path;
import std.datetime;
import std.conv : to;

/// struct to make backups
struct BakMan{
	/// returns the date the last backup was done
	static SysTime lastBackupDate(string filePath){
		string backupDir = filePath.dirName~"/backups";
		string fName = baseName(filePath);
		string[] files = listdir(backupDir~'/');
		// they're stored like: bakName.1.tar.gz, bakName.2.tar.gz .. where 2 is newer than 1
		// get latest
		uinteger minNameLength = fName.length+9; // fName.length+".X.tar.gz"
		// the date modified of the latest backup
		SysTime latestDate;
		uinteger latestCount = 0;
		foreach(bakFile; files){
			if (bakFile.length >= minNameLength && bakFile[0 .. fName.length] == fName &&
				bakFile[bakFile.length-7 .. bakFile.length] == ".tar.gz"){
				string count = bakFile[fName.length+1 .. bakFile.length-7];
				if (count.isNum){
					// ok, this is a backup
					if (to!uinteger(count) > latestCount){
						latestDate = timeLastModified(backupDir~'/'~bakFile);
						latestCount = to!uinteger(count);
					}
				}
			}
		}
		return latestDate;
	}

	/// returns the relative file path of the latest backups

	/// returns true if a file/any-file-in-a-dir was modified after a data/time
	static bool hasModified(string filePath, SysTime backupDate){
		string backupDir = filePath.dirName~"/backups";
		// now check if any file in that dir, or if it is a file, then if it's been modified after backup, then make another
		if (filePath.isDir){
			// recursion for all the files
			string[] dirFiles = listdir(filePath);
			foreach (file; dirFiles){
				if (hasModified(file, backupDate)){
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
	/// reads config from a file
	void openConfig(string file){
		import std.variant;
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
		// done!
		changed = false;
		filename = file;
	}
	/// saves the config file back to disk, whether changed or not
	/// 
	/// `file` is the name of file to write to
	void saveConfig(string file){
		// prepare the tags
		Tag[] tags;
		tags.length = filePaths.length+3;
		Tag rootTag = new Tag();
		foreach (i, filePath; filePaths){
			tags[i] = new Tag(rootTag,"","file",[Value(filePath)]);
		}
		tags[filePaths.length .. tags.length] = [
			new Tag(rootTag,"","overwriteExisting",[Value(overwriteExisitng)]),
			new Tag(rootTag,"","backupStartCommand",[Value(backupStartCommand)]),
			new Tag(rootTag,"","backupFinishCommand",[Value(backupFinishCommand)])
		];
		// add them all to the rootTag
		foreach (tag; tags){
			rootTag.add(tag);
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