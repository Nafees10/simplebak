import std.datetime;
import std.process;
import std.stdio;
import std.path;
import std.file;
import bak;

import utils.misc;

const VERSION = "0.1.0";
const CONF_PATH = "~/.config/simplebak/conf.sdl";

/*
Args format:
	simplebak [command]
Commands:
	add 	- adds a new file/dir for backup.
	remove 	- removes a file/dir from list of files to make backup of.
	backup	- makes backup of only a specified file, if needed
	help	- displays this message
	version	- displays the version
	list	- lists all files that are added
*/
void main(string[] args){
	if (args.length > 1){
		if (args[1] == "help" || args[1] == "--help"){
			write(
				"Usage:
\tsimplebak [command]
Commands:
\tadd     - adds a new file/dir for making backups in future
\tremove  - removes a file/dir from list of files to make backup of
\tbackup  - makes backup of only a specific file/dir, if modified
\tlist    - displays list of all files/dirs to include in future backups
\thelp    - displays this message
\tversion - displays the version\n
Run without any command to start make backup of all added files/dirs\n"
				);
		}else if (args[1] == "version"){
			writeln (VERSION);
		}else{
			// load the conf file
			ConfigFile conf;
			conf.openConfig(expandTilde(CONF_PATH));
			if (args[1] == "add"){
				// check if is valid path
				if (args.length < 3){
					writeln ("No file/dir specified to add to backups");
				}else if (!args[2].exists){
					writeln ("Filename specified does not exist");
				}else{
					// now just add it
					conf.filePaths = conf.filePaths ~ absolutePath(args[2]);
					writeln (baseName(args[2])~" added");
				}
			}else if (args[1] == "remove"){
				// check if specified
				if (args.length < 3){
					writeln ("No file/dir specifed to remove from future backups");
				}else if (conf.filePaths.indexOf(absolutePath(args[2])) < 0){
					writeln (baseName(args[2])~" was never added, cannot be removed");
				}else{
					// remove it
					uinteger index = conf.filePaths.indexOf(args[2].absolutePath);
					conf.filePaths = conf.filePaths.deleteElement(index);
					writeln (baseName(args[2])~" removed from future backups");
				}
			}else if (args[1] == "backup"){
				if (args.length < 3){
					writeln ("No file/dir specified to make backup of");
				}else if (conf.filePaths.indexOf(absolutePath(args[2])) < 0){
					writeln (baseName(args[2])~" does not exist in files to make backup of.\nAdd it using 'simplebak add ...'");
				}else if (!args[2].exists){
					writeln ("Filename specified does not exist");
				}else{
					// just make the backup now
					// execute start command
					if (conf.backupStartCommand != ""){
						writeln ("Executing pre-makeBackup shell command:");
						writeln ("Command returned: ",executeShell(conf.backupStartCommand).output);
					}
					string fullPath = absolutePath(args[2]);
					if (BakMan.hasModified(fullPath, BakMan.lastBackupDate(fullPath))){
						writeln (baseName(args[2])~" has been modified, making new backup");
						if (!BakMan.makeBackup(fullPath)){
							writeln ("Backup failed");
							if (conf.backupFailCommand != ""){
								writeln ("Executing backup-fail shell command:");
								writeln ("Command returned: ", executeShell(conf.backupFailCommand).output);
							}
						}else{
							writeln ("Backup successful");
						}
					}else{
						writeln (baseName(args[2])~" not modified since last backup, skipping");
					}
				}
				writeln ("Backup finished");
				// execute backup-end-command
				if (conf.backupFinishCommand != ""){
					writeln ("Executing backup-finish shell command:");
					writeln ("Command returned: ", executeShell(conf.backupFinishCommand).output);
				}
			}else if (args[1] == "list"){
				foreach (filePath; conf.filePaths){
					writeln (filePath);
				}
			}else{
				writeln (args[1], "is not a valid command.\nType 'simplebak help' for list of available commands");
			}
			// save the conf file
			conf.saveConfig();
		}
	}else{
		// load the conf file
		ConfigFile conf;
		conf.openConfig(expandTilde(CONF_PATH));
		writeln ("Total Files to make backup for: ", conf.filePaths.length);
		// execute start command
		if (conf.backupStartCommand != ""){
			writeln ("Executing pre-makeBackup shell command:");
			writeln ("Command returned: ",executeShell(conf.backupStartCommand).output);
		}
		// check if any files have been modified, then make backup
		foreach (file; conf.filePaths){
			// get backup date
			SysTime backupDate = BakMan.lastBackupDate(file);
			// now see if modified, then back it up
			if (BakMan.hasModified(file, backupDate)){
				writeln (file, " has been modified, making new backup");
				if (!BakMan.makeBackup(file)){
					writeln ("Backup failed");
					if (conf.backupFailCommand != ""){
						writeln ("Executing backup-fail shell command:");
						writeln ("Command returned: ", executeShell(conf.backupFailCommand).output);
					}
				}else{
					writeln ("Backup successful");
				}
			}else{
				writeln (file, " not modified since last backup, skipping");
			}
		}
		writeln ("Backup finished");
		// execute backup-end-command
		if (conf.backupFinishCommand != ""){
			writeln ("Executing backup-finish shell command:");
			writeln ("Command returned: ", executeShell(conf.backupFinishCommand).output);
		}
		// save the conf file
		conf.saveConfig();
	}
}
