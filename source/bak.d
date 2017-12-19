module bak;

import sdlang;
import std.file;
import std.path;

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