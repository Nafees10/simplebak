import core.stdc.stdlib;
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
	/// stores the exit code to exit with
	int exitCode = 0;
	if (args.length == 1 || args[1] == "help" || args[1] == "--help" || args[1] == "-h"){
		write(
				"Usage:
\tsimplebak [command]
Commands:
\tadd     - adds new files/dirs for making backups in future
\tremove  - removes files/dirs from list of files to make backup of
\tbackup  - makes backup of all added files/dirs
\tlist    - displays list of all files/dirs to include in future backups
\thelp    - displays this message
\tversion - displays the version\n
Run without any command to start make backup of all added files/dirs\n"
		);
	}
	if (args.length > 1){
		if (args[1] == "version"){
			writeln (VERSION);
		}else{
			// load the conf file
			ConfigFile conf;
			conf.openConfig(expandTilde(CONF_PATH));
			if (args[1] == "add"){
				// check if is valid path
				if (args.length < 3){
					writeln ("No file/dir specified to add to backups");
					exitCode = 1;
				}else if (!args[2].exists){
					// check if all files actually exist, add those that exist, ignore those that don't
					/// stores how many files were not added
					uinteger notAddedCount = 0;
					foreach (filePath; args[2 .. args.length]){
						if (filePath.exists){
							conf.filePaths = conf.filePaths ~ absolutePath(filePath);
							writeln (filePath~" added");
						}else{
							notAddedCount ++;
							writeln (filePath~" does not exist, not added");
						}
					}
					if (notAddedCount > 0){
						writeln (notAddedCount," files/dirs were not added");
						exitCode = 1;
					}
				}
			}else if (args[1] == "remove"){
				// check if specified
				if (args.length < 3){
					writeln ("No file/dir specifed to remove from future backups");
					exitCode = 1;
				}else{
					// check if each file was added before, remove those that were added
					/// stores how many files/dirs were not removed
					uinteger notRemovedCount = 0;
					foreach (filePath; args[2 .. args.length]){
						integer index =conf.filePaths.indexOf(absolutePath(filePath));
						if (index >= 0){
							conf.filePaths = conf.filePaths.deleteElement(index);
							writeln (filePath~" remove from future backups");
						}else{
							notRemovedCount ++;
							writeln (filePath~" was never added, cannot be removed");
						}
					}
					if (notRemovedCount > 0){
						writeln (notRemovedCount," files/dirs were not removed");
						exitCode = 1;
					}
				}
			}else if (args[1] == "list"){
				foreach (filePath; conf.filePaths){
					writeln (filePath);
				}
			}else if (args[1] == "backup"){
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
							exitCode = 1;
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
			}else{
				writeln (args[1], "is not a valid command.\nType 'simplebak help' for list of available commands");
			}
			// save the conf file
			conf.saveConfig();
		}
	}
	exit(exitCode);
}
