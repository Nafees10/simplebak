/+
Contains structs to read sdl files, including the conf.sdl file, and bakinfo.sdl files
+/
module conf;

import utils.misc;
import sdlang;
import std.file;
import std.path;
import std.variant;
import std.datetime;

/// represents the conf.sdl config file
/// 
/// makes reading and writing to it easier
class ConfigFile{
	/// stores whether the file has been changed in memory after loading
	private bool changed=false;
	/// stores filename of currently open file
	private string filename;
	/// stores the file paths which have to be included in backups
	private string[] _filePaths;
	/// array of files to include in backups
	@property string[] filePaths(){
		return _filePaths.dup;
	}
	/// array of files to include in backups
	@property string[] filePaths(string[] newVal){
		changed = true;
		_filePaths = newVal.dup;
		return newVal;
	}
	/// stores the file paths which are to be excluded from backups
	private string[] _exclude;
	/// returns: array of filepaths to exclude in backups
	@property string[] excludeList(){
		return _exclude.dup;
	}
	/// array of filepaths to exclude in backups
	@property string[] excludeList(string[] newList){
		changed = true;
		_exclude = newList.dup;
		return newList;
	}
	/// stores the dir that will store the backups
	private string _backupDir;
	/// the dir storing the backups
	@property string backupDir(){
		return _backupDir;
	}
	/// the dir storing the backups
	@property string backupDir(string newDir){
		changed = true;
		_backupDir = newDir;
		return newDir;
	}
	/// reads config from a file
	void openConfig(string file){
		if (exists(file)){
			Tag rootTag = parseFile(file);
			// read the backup dir
			_backupDir = rootTag.getTagValue!string("backupDir",expandTilde ("~/backups"));
			// read values now
			auto filesRange = rootTag.getTag("fileList").tags;
			_filePaths.length = filesRange.length;
			uinteger i = 0;
			while (!filesRange.empty){
				Tag fileTag = filesRange.front;
				filesRange.popFront;
				if (fileTag.getFullName.toString != "file"){
					_filePaths.length --;
					continue;
				}else{
					_filePaths[i] = fileTag.getValue!string;
				}
				i ++;
			}
			// excludeList
			filesRange = rootTag.getTag("excludeList").tags;
			_exclude.length = filesRange.length;
			i = 0;
			while (!filesRange.empty){
				Tag fileTag = filesRange.front;
				filesRange.popFront;
				if (fileTag.getFullName.toString != "exclude"){
					_exclude.length --;
					continue;
				}else{
					_exclude[i] = fileTag.getValue!string;
				}
				i ++;
			}
			changed = false;
		}else{
			// file didnt exist, to make it, set changed=true
			changed = true;
			_backupDir = expandTilde ("~/backups");
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
			backupDirTag = new Tag(rootTag, "", "backupDir", [Value (_backupDir)]);
		Tag[] fileTags, excludeTags;
		
		fileTags.length = _filePaths.length;
		foreach (i, path; _filePaths){
			fileTags[i] = new Tag(fileListTag, "", "file", [Value(path)]);
		}
		excludeTags.length = _exclude.length;
		foreach (i, path; _exclude){
			excludeTags[i] = new Tag(excludeListTag, "", "exclude", [Value(path)]);
		}
		// if dir doesnt exist, make it
		if (!dirName(file).exists){
			mkdirRecurse(file.dirName);
		}
		write(file, rootTag.toSDLDocument);
		// destroy all the tags
		foreach (tag; [rootTag, fileListTag, excludeListTag]~fileTags~excludeTags){
			.destroy(tag);
		}
		changed = false;
	}
	/// saves the config back to same file as was read from, only if changed
	void saveConfig(){
		if (changed){
			saveConfig(filename);
		}
	}
}

/// To read and write to the bakinfo.sdl files
/// 
/// bakinfo.sdl contains the following info about a backup
/// 
/// 1. Time when backup was created
/// 2. which files were modified (relative to the previous backup)
/// 3. which files were deleted (relative to the previous backup)
/// 4. which files were created (relative to the previous backup)
/// 5. which files existed at that time
class BakInfo{
private:
	/// stores whether the file has been modified after being loaded
	bool changed;
	/// stores filename of currently open file
	string filename;
	/// stores the time the backup was made
	SysTime _backupTime;
	/// stores list of files which were modified
	string[] _modifiedFiles;
	/// stores list of files which were deleted
	string[] _deletedFiles;
	/// stores list of files which were created
	string[] _createdFiles;
	/// stores list of files that existed
	string[] _existingFiles;
public:
	/// constructor
	this (){
		changed = false;
		// by default, backupTime is current time
		_backupTime = Clock.currTime;
	}
	/// time backup was made
	@property SysTime backupTime(){
		return _backupTime;
	}
	/// time backup was made
	@property SysTime backupTime(SysTime newTime){
		changed = true;
		_backupTime = newTime;
		return newTime;
	}
	
	/// array of files that were modified
	@property string[] modifiedFiles(){
		return _modifiedFiles.dup;
	}
	/// array of files that were modified
	@property string[] modifiedFiles(string[] newArray){
		_modifiedFiles = newArray.dup;
		changed = true;
		return newArray;
	}
	
	/// array of files that were deleted
	@property string[] deletedFiles(){
		return _deletedFiles.dup;
	}
	/// array of files that were deleted
	@property string[] deletedFiles(string[] newArray){
		_deletedFiles = newArray.dup;
		changed = true;
		return newArray;
	}
	
	/// array of files that were created
	@property string[] createdFiles(){
		return _createdFiles.dup;
	}
	/// array of files that were created
	@property string[] createdFiles(string[] newArray){
		_createdFiles = newArray.dup;
		changed = true;
		return newArray;
	}

	/// array of files that existed at time of backup
	@property string[] existingFiles(){
		return _existingFiles.dup;
	}
	/// array of files that existed at time of backup
	@property string[] existingFiles(string[] newArray){
		_existingFiles = newArray.dup;
		changed = true;
		return newArray;
	}
	
	/// opens a SDL file and reads it into this struct
	/// 
	/// Throws: Exception if file doesnt exist
	void open(string file){
		if (file.exists){
			Tag rootTag = parseFile(file);
			// read the backup time
			_backupTime = SysTime.fromISOExtString (rootTag.getTagValue!string("backupTime"));
			// read modified, created, and deleted list
			/// [0] is modifiedRange, [1] is deleted, [2] is created
			auto tagRanges = [
				rootTag.getTag("modified").tags,
				rootTag.getTag("deleted").tags,
				rootTag.getTag("created").tags,
				rootTag.getTag("existing").tags
				];
			/// stores the read-ed string from the above ranges
			string[][4] readValues;
			foreach (index, tagRange; tagRanges){
				readValues[index].length = tagRange.length;
				uinteger i = 0;
				while (!tagRange.empty){
					Tag fileTag = tagRange.front;
					tagRange.popFront;
					if (fileTag.getFullName.toString != "file"){
						readValues[index].length --;
						continue;
					}else{
						readValues[index][i] = fileTag.getValue!string;
					}
					i ++;
				}
			}
			// put them into the apporpriate arrays
			_modifiedFiles = readValues[0];
			_deletedFiles = readValues[1];
			_createdFiles = readValues[2];
			_existingFiles = readValues[3];
			
			changed = false;
			filename = file;
		}else{
			// file didnt exist, so throw an Exception
			throw new Exception (file~" doesn't exist");
		}
	}

	/// saves this sdl file to an actual file
	void save(string file){
		// prepare tags
		Tag rootTag = new Tag(),
			modifiedTag = new Tag(rootTag, "", "modified"),
			deletedTag = new Tag(rootTag, "", "deleted"),
			createdTag = new Tag(rootTag, "", "created"),
			existingTag = new Tag(rootTag, "", "existing"),
			backupTimeTag = new Tag(rootTag, "", "backupTime", [Value(backupTime.toISOExtString)]);
		/// the "list" tags, i.e, inside the modified, deleted, and created. [0] is modified, [1] is deleted, [2] is created
		Tag[][4] fileListTags;
		foreach (index, files; [_modifiedFiles, _deletedFiles, _createdFiles, _existingFiles]){
			fileListTags[index].length = files.length;
			Tag tagToPutIn = index == 0 ? modifiedTag : (index == 1 ? deletedTag : (index == 2 ? createdTag : existingTag));
			foreach (i, filePath; files){
				fileListTags[index][i] = new Tag(tagToPutIn, "", "file", [Value(filePath)]);
			}
		}
		// if dir doesnt exist, make it
		if (!dirName(file).exists){
			mkdirRecurse(file.dirName);
		}
		write(file, rootTag.toSDLDocument);
		// destroy all tags
		foreach (tags; fileListTags){
			foreach (tag; tags){
				.destroy(tag);
			}
		}
		foreach (tag; [rootTag, modifiedTag, deletedTag, createdTag, existingTag, backupTimeTag]){
			.destroy(tag);
		}
		changed = false;
	}
	/// saves the file, to the original file from where it was read from, only if changed
	void save(){
		if (changed){
			save (filename);
		}
	}
}
