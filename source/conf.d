module conf;

import utils.misc;
import sdlang;
import std.file;
import std.path;

/// represents the simplebak.sdl config file
/// 
/// makes reading and writing to it easier
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
	/// stores the dir that will store the backups
	private string storedBackupDir;
	/// the dir storing the backups
	@property string backupDir(){
		return storedBackupDir;
	}
	/// the dir storing the backups
	@property string backupDir(string newDir){
		changed = true;
		storedBackupDir = newDir;
		return newDir;
	}
	/// reads config from a file
	void openConfig(string file){
		import std.variant;
		if (exists(file)){
			Tag rootTag = parseFile(file);
			// read the backup dir
			storedBackupDir = rootTag.getTagValue!string("backupDir","~/backups");
			// read values now
			auto filesRange = rootTag.getTag("fileList").tags;
			storedFilePaths.length = filesRange.length;
			uinteger i = 0;
			while (!filesRange.empty){
				Tag fileTag = filesRange.front;
				filesRange.popFront;
				if (fileTag.getFullName.toString != "file"){
					storedFilePaths.length --;
				}else{
					storedFilePaths[i] = fileTag.getValue!string;
				}
				i ++;
			}
			// excludeList
			filesRange = rootTag.getTag("excludeList").tags;
			storedExclude.length = filesRange.length;
			i = 0;
			while (!filesRange.empty){
				Tag fileTag = filesRange.front;
				filesRange.popFront;
				if (fileTag.getFullName.toString != "exclude"){
					storedExclude.length --;
				}else{
					storedExclude[i] = fileTag.getValue!string;
				}
				i ++;
			}
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
		Tag rootTag = new Tag(),
			fileListTag = new Tag(rootTag,"","fileList"),
			excludeListTag = new Tag(rootTag,"","excludeList"),
			backupDirTag = new Tag(rootTag, "", "backupDir", [Value (storedBackupDir)]);
		Tag[] fileTags, excludeTags;
		
		fileTags.length = storedFilePaths.length;
		foreach (i, path; storedFilePaths){
			fileTags[i] = new Tag(fileListTag, "", "file", [Value(path)]);
		}
		excludeTags.length = storedExclude.length;
		foreach (i, path; storedExclude){
			excludeTags[i] = new Tag(excludeListTag, "", "exclude", [Value(path)]);
		}
		// if dir doesnt exist, make it
		if (!dirName(file).exists){
			mkdirRecurse(file.dirName);
		}
		write(file, rootTag.toSDLDocument);
		// destroy all the tags
		.destroy(rootTag);
		foreach (tag; [rootTag, fileListTag, excludeListTag]~fileTags~excludeTags){
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
