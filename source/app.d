import std.stdio;
import std.path;
import std.file;
import bak;

const VERSION = "0.1.0";
const CONF_PATH = "~/.config/simplebak/conf.sdl";

/*
Args format:
	simplebak [command]
Commands:
	add 	- adds a new file/dir for backup.
	remove 	- removes a file/dir from list of files to make backup of.
	restore	- restores the last, or n-th last backup for a file, n is arg
	help	- displays this message
	version	- displays the version
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
				// check if file exists
				// check if is valid path
				if (args.length < 3){
					writeln ("No file/dir specified to add to backups");
				}else{
					if (!args[2].isValidFilename){
						writeln ("Invalid filename specified");
					}else if (!args[2].exists){
						writeln ("Filename specified does not exist");
					}else{
						// now just add it
						conf.filePaths = conf.filePaths ~ args[2];
						writeln (baseName(args[2])~" added");
					}
				}
			}else if (args[1] == "remove"){
				// check if it exists in the tobak.sdl
				// TODO implement remove command
			}else{
				writeln (args[1], "is not a valid command.\nType 'simplebak help' for list of available commands");
			}
			// save the conf file
			conf.saveConfig();
		}
	}else{
		// TODO make backup
	}
}
