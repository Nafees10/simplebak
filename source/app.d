import core.stdc.stdlib;
import std.datetime;
import std.process;
import std.stdio;
import std.path;
import std.file;
import conf;
import bak;

import utils.misc;

const VERSION = "1.0.0"; /// version
const CONF_PATH = "~/.config/simplebak/conf.sdl"; /// file to store config

/*
Args format:
	simplebak [command]
Commands:
	add 	- adds a new file/dir for backup.
	exclude - excludes a file/dir from being included in any backup.
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
\texclude - excludes a file/dir from being included in any backup
\tremove  - removes files/dirs from list of files to make backup of
\tbackup  - makes backup of all added files/dirs
\tlist    - displays list of all files/dirs to include in future backups
\thelp    - displays this message
\tversion - displays the version\n"
		);
	}else if (args.length > 1){
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
				}else{
					// even if files/dirs don't exist, they will be added, coz they might exist in the future...
					foreach (filePath; args[2 .. args.length]){
						conf.filePaths = conf.filePaths ~ absolutePath(filePath);
					}
					writeln (args.length - 2," files/dirs added");
				}
			}else if (args[1] == "exclude"){
				if (args.length < 3){
					writeln ("No file/dir specified to be excluded from backups");
					exitCode = 1;
				}else{
					foreach (filePath; args[2 .. args.length]){
						conf.excludeList = conf.excludeList ~ absolutePath(filePath);
					}
				}
			}else if (args[1] == "remove"){
				// check if specified
				if (args.length < 3){
					writeln ("No file/dir specifed to remove from future backups");
					exitCode = 1;
				}else{
					// check if each file was added before, remove those that were added, ignore the rest
					uinteger count = 0;
					foreach (filePath; args[2 .. args.length]){
						integer index = conf.filePaths.indexOf(absolutePath(filePath));
						if (index >= 0){
							conf.filePaths = conf.filePaths.deleteElement(index);
							count ++;
						}
					}
					writeln (count, "files/dirs removed from future backups");
				}
			}else if (args[1] == "list"){
				foreach (filePath; conf.filePaths){
					writeln (filePath);
				}
			}else if (args[1] == "backup"){
				// TODO
			}else{
				writeln (args[1], "is not a valid command.\nType 'simplebak help' for list of available commands");
			}
			// save the conf file
			conf.saveConfig();
		}
	}
	exit(exitCode);
}
