# Patch generation tool

## Description
Generates a patch for a single branch of a single repository using 'git diff'.

## Requirements
/bin/bash

## Installation`
* Clone this repository into your own folder
```
git clone https://github.com/katmoon/create-patch.git
```
* (Optional; for *nix systems) create symlink for converter into the bin folder
```
curl -o create-git-patch.sh https://raw.githubusercontent.com/katmoon/create-patch/main/create-git-patch.sh
ln -s `pwd`/create-git-patch.sh ~/bin/
chmod +x ~/bin/create-git-patch.sh
```

## Usage
```
> create-git-patch.sh -h
Usage: sh create-git-patch.sh [--help] [-b <branch>] [-v <version>] [-r <commit>:<commit>]
Generate patch by collecting changes from latest tag till HEAD (by default).

-b <branch>             Specify the branch. Example: ABCD-1234.

-v <version>            Specify the patch version. Examples: v2, DEBUG, DEBUG_v2.

-r <commit>:<commit>    Collect patch using changes between two arbitrary <commit>
                        Patch is generating by "git diff" tool, so this range treated in the same way as "git diff" command does,
                        thus if <commit> on one side is omitted, it will have the same effect as using HEAD instead.
                        If this option will be omitted at all - patch will be generated using changes between latest tag and HEAD.

--help                  Show this help message
```
