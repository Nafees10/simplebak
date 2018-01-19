# simplebak
A simple backup program, written in D Language.  
_simplebak has only been tested on (xubuntu) GNU/Linux, and will (probably) not work with Windows_

---

## Getting Started
simplebak reqiures some programs to be pre-installed on your system, which are:
* tar - usually preinstalled on most GNU/Linux distros
* bash as default shell
* a DLang compiler (dmd) and dub package manager - to compile simplebak

### Installing
1. install all the prerequisites, listed above
2. download a stable release from [Releases](https://github.com/Nafees10/simplebak/releases)
4. extract the archive, use `tar -xf` or anything else
5. `cd` into the extracted directory, and run `dub --build=release`
6. copy `simplebak` executable file to `/usr/local/bin/simplebak` or somewhere where the shell can find it

### Usage
#### Adding files for backup
To make simplebak make backups of a file or directory, use this:  
`simplebak add /file/to/make/backup/of`
#### Removing files from future backups
To stop simplebak from making any more backups of a file/dir, use this:  
`simplebak remove /file/to/no/more/make/backup/of`
#### List files/dirs to make backup of
To get list of all files/directories of which backups will be made, use this:  
`simplebak list`
#### Make backup of all added files
To make backup of all added files/directories, which were added using `simplebak add ...`, simply execute this:  
`simplebak`
#### Make backup of a specific file/directory
To make backup of only a specific file/directory, make sure that that file/directory was first added using `simplebak add ...`, then execute this:  
`simplebak backup /file/to/backup`

---

## Config file
simplebak stores its configurations in `~/.config/simplebak/conf.sdl`. You can add more files, or change some configurations by editing this file.  
Below is a list of what each Tag (SDL tags) specifies:  
* `file` - all the files backup are listed after this enclosed in quotation marks
* `backupStartCommand` - This is a shell command that will be executed right before simplebak starts making backups
* `backupFinishCommand` - This is a shell command that will be executed after all backups (or single backup if called using `simplebak backup`) are made, it is called whether 
there was an error or not
* `backupFailCommand` - This shell command will be executed when making a backup fails

---

## License
simplebak is licensed under MIT license, contained in `LICENSE.md`

## Acknowledgments
* My laptop crashing, leading to a messed up [minetest](https://www.minetest.net/) world, forcing me to keep backups.