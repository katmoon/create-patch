#!/usr/bin/env bash
# Git patch creation tool
# v1.0
# (c) Copyright 2023 Adobe Commerce.

# 1. Check required system tools

_check_installed_tools() {
    local missed=""

    until [ -z "$1" ]; do
        type -t $1 >/dev/null 2>/dev/null
        if (( $? != 0 )); then
            missed="$missed $1"
        fi
        shift
    done

    echo $missed
}

REQUIRED_UTILS='git cat grep basename awk head pwd dirname'
MISSED_REQUIRED_TOOLS=`_check_installed_tools $REQUIRED_UTILS`
if (( `echo $MISSED_REQUIRED_TOOLS | wc -w` > 0 ));
then
    echo -e "Error! Some required system tools, that are utilized in this sh script, are not installed:\nTool(s) \"$MISSED_REQUIRED_TOOLS\" is(are) missed, please install it(them)."
    exit 1
fi

# Determine bin path for system tools
GIT_BIN=`which git`
CAT_BIN=`which cat`
GREP_BIN=`which grep`
BASENAME_BIN=`which basename`
AWK_BIN=`which awk`
HEAD_BIN=`which head`
PWD_BIN=`which pwd`
DIRNAME_BIN=`which dirname`

BASE_NAME=`$BASENAME_BIN "$0"`


# 2. Load env variables

TOOL_DIR=$($DIRNAME_BIN "$0")
ENV_FILE_PATH="$TOOL_DIR"/.env
if [ -f "$ENV_FILE_PATH" ]
then
    source $ENV_FILE_PATH
    echo "Loaded .env from $ENV_FILE_PATH."
else
   echo -e "$ENV_FILE_PATH was not found. Copy .env.example to .env and specify the path to the converter tool."
fi

# 3. Help menu

if [ "$1" = "-?" -o "$1" = "-h" -o "$1" = "--help" ]
then
    $CAT_BIN << EOFH
Usage: sh $BASE_NAME [--help] [-b <branch>] [-r <release version>] [-v <version>] [-c <commit>:<commit>]
Generate a patch by collecting changes from the latest tag to HEAD (by default).
The tool should be run from the directory containing the repository.

-b <branch>             Specify the branch. Example: ABCD-1234.

-r <release version>    [Optional] Specify the release version to use for the patch file name.
                        If not specified, the tool will try to identify the release version based on the latest tag.

-v <patch version>      Specify the patch version. Examples: v2, DEBUG, DEBUG_v2. Leave empty for v1.

-c <commit>:<commit>    [Optional] Collect patch using changes between two arbitrary <commit>
                        Patch is generating by "git diff" tool, so this range treated in the same way as "git diff" command does,
                        that is if <commit> on one side is omitted, it will have the same effect as using HEAD instead.
                        If this option will be omitted at all, the patch will be generated using the changes between the latest tag and HEAD.

--help                  Show this help message
EOFH
    exit 0
fi

# 4. Get options

BRANCH=
PATCH_VERSION=
COLLECT_REVISIONS_RANGE=
while getopts b:v:r: opt; do
    case $opt in
    b)
        BRANCH="$OPTARG"
        ;;
    r)
        RELEASE_VERSION="$OPTARG"
        ;;
    v)
        PATCH_VERSION="$OPTARG"
        ;;
    c)
        COLLECT_REVISIONS_RANGE="$OPTARG"
        ;;
    esac
done

# 5. Git preparations

_check_git_revision() {
    CHECK_COMMIT=`$GIT_BIN rev-list HEAD.."$1" > /dev/null 2>&1`
    CHECK_COMMIT_RESULT=$?
    if [ ! $CHECK_COMMIT_RESULT -eq 0 ] ; then
        echo -e "ERROR: Wrong/none-existing revisions range was specified."
        exit 1
    fi
}

# Determine if current directory is under git control
IS_UNDER_GIT_CONTROL=777
git rev-parse -q
IS_UNDER_GIT_CONTROL=$?
if [ ! $IS_UNDER_GIT_CONTROL -eq 0 ] ; then
    echo -e "ERROR: Patch can't be created because current directory is not under Git control."
    exit 1
fi

# Checkout branch
if [ -n "$BRANCH" ] ; then
    $GIT_BIN fetch
    $GIT_BIN checkout $BRANCH
    if [ $? -ne 0 ]; then
      echo -e "ERROR: Branch $BRANCH was not found."
      exit 1
    fi
    $GIT_BIN merge
fi

# Get latest tag in current branch
CURRENT_TAG=`$GIT_BIN describe --abbrev=0 --tags`

# If revisions range was omitted, then set range from current tag to HEAD
if [ -z "$COLLECT_REVISIONS_RANGE" ]
then
    COLLECT_REVISIONS_RANGE="$CURRENT_TAG..HEAD"
    START_COMMIT=`$GIT_BIN rev-list "$CURRENT_TAG" | $HEAD_BIN -n 1`
else
    START_COMMIT=`echo "$COLLECT_REVISIONS_RANGE" | $AWK_BIN -F ":" '{print $1}'`
    END_COMMIT=`echo "$COLLECT_REVISIONS_RANGE" | $AWK_BIN -F ":" '{print $2}'`

    # Check if specified "start" and "end" commits are exist
    _check_git_revision "$START_COMMIT"

    # If "end" commit was specified (not empty), set revisions range in applicable format for "git diff" command
    if [ ! -z "$END_COMMIT" ]
    then
        _check_git_revision "$END_COMMIT"
        COLLECT_REVISIONS_RANGE="$START_COMMIT..$END_COMMIT"
    fi

fi

echo "======== Commits in the patch: ========"
$GIT_BIN log --oneline -20 $COLLECT_REVISIONS_RANGE
echo "======== Based on: ===================="
$GIT_BIN log --oneline -1 `git rev-parse $START_COMMIT`
echo "======================================="

# 6. Patch tool file name

CURRENT_BRANCH=`$GIT_BIN rev-parse --abbrev-ref HEAD`
TICKET_NUMBER=$(echo "$CURRENT_BRANCH" | $GREP_BIN -oE '^[A-Z]*-[0-9]*')

if [ -n "$RELEASE_VERSION" ] ; then
    MAGENTO_VERSION=$RELEASE_VERSION
else
    MAGENTO_VERSION=`echo $CURRENT_TAG | $AWK_BIN '{gsub("v",""); print}'`
fi


if [[ "$PATCH_VERSION" == "v1" ]] || [[ -z "$PATCH_VERSION" ]]
then
    PATCH_VERSION_SUFFIX=
else
    PATCH_VERSION_SUFFIX="_$PATCH_VERSION"
fi
PATCH_FILE_NAME_GIT="$TICKET_NUMBER""_""$MAGENTO_VERSION""$PATCH_VERSION_SUFFIX"".git.patch"
PATCH_FILE_NAME_COMPOSER="$TICKET_NUMBER""_""$MAGENTO_VERSION""$PATCH_VERSION_SUFFIX"".patch"


# 7. Create the patch file

$GIT_BIN diff -a -p $COLLECT_REVISIONS_RANGE > $PATCH_FILE_NAME_GIT

# Create a composer version of the file
CURRENT_DIR=`$PWD_BIN`
PATCH_FILE_PATH_GIT="$CURRENT_DIR"/"$PATCH_FILE_NAME_GIT"
PATCH_FILE_PATH_COMPOSER="$CURRENT_DIR"/"$PATCH_FILE_NAME_COMPOSER"
if [ -n $PATCH_CONVERTER_TOOL_BIN ]
then
    $PATCH_CONVERTER_TOOL_BIN $PATCH_FILE_PATH_GIT > $PATCH_FILE_PATH_COMPOSER
fi


# 8. Report results

if [ -f "$PATCH_FILE_PATH_GIT" ] && [ $(wc -c < "$PATCH_FILE_PATH_GIT") -gt 1 ]
then
    echo "Git patch generated successfully."
    echo "Git patch location: $PATCH_FILE_PATH_GIT"
else
    echo "Something went wrong when generating the patch."
fi
if [ -f "$PATCH_FILE_PATH_COMPOSER" ] && [ $(wc -c < "$PATCH_FILE_PATH_COMPOSER") -gt 1 ]
then
    echo "Composer patch generated successfully."
    echo "Composer patch location: $PATCH_FILE_PATH_COMPOSER"
else
    echo "Something went wrong when generating the composer patch. Recheck the converter tool location."
fi
exit 0