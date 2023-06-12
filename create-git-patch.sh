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

REQUIRED_UTILS='git cat grep basename awk head pwd'
MISSED_REQUIRED_TOOLS=`_check_installed_tools $REQUIRED_UTILS`
if (( `echo $MISSED_REQUIRED_TOOLS | wc -w` > 0 ));
then
    echo -e "Error! Some required system tools, that are utilized in this sh script, are not installed:\nTool(s) \"$MISSED_REQUIRED_TOOLS\" is(are) missed, please install it(them)."
    exit 1
fi

# 2. Determine bin path for system tools
GIT_BIN=`which git`
CAT_BIN=`which cat`
GREP_BIN=`which grep`
BASENAME_BIN=`which basename`
AWK_BIN=`which awk`
HEAD_BIN=`which head`
PWD_BIN=`which pwd`

BASE_NAME=`$BASENAME_BIN "$0"`

# 3. Help menu
if [ "$1" = "-?" -o "$1" = "-h" -o "$1" = "--help" ]
then
    $CAT_BIN << EOFH
Usage: sh $BASE_NAME [--help] [-b <branch>] [-v <version>] [-r <commit>:<commit>]
Generate patch by collecting changes from latest tag till HEAD (by default).

-b <branch>             Specify the branch. Example: ABCD-1234.

-v <version>            Specify the patch version. Examples: v2, DEBUG, DEBUG_v2.

-r <commit>:<commit>    Collect patch using changes between two arbitrary <commit>
                        Patch is generating by "git diff" tool, so this range treated in the same way as "git diff" command does,
                        thus if <commit> on one side is omitted, it will have the same effect as using HEAD instead.
                        If this option will be omitted at all - patch will be generated using changes between latest tag and HEAD.

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
    v)
        PATCH_VERSION="$OPTARG"
        ;;
    r)
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
    COLLECT_REVISIONS_RANGE=""$CURRENT_TAG"..HEAD"
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
        COLLECT_REVISIONS_RANGE="$START_COMMIT""..""$END_COMMIT"
    fi

fi

echo "======== Commits in the patch: ========"
$GIT_BIN log --oneline -20 $COLLECT_REVISIONS_RANGE
echo "=========================="


# 6. Patch tool file name

CURRENT_BRANCH=`$GIT_BIN rev-parse --abbrev-ref HEAD`
# Dev branch name must be determined using the latest tag
DEV_BRANCH_NAME=`$GIT_BIN branch -a --contains "$CURRENT_TAG" | $GREP_BIN origin/v[.0123456789-p]* | $HEAD_BIN -n 1`
# DEV_BRANCH_NAME can contain string like this "  remotes/origin/v2.4.3-p3"
# thus it must be taken into account 2 spaces in it
MAGENTO_VERSION=`echo ${DEV_BRANCH_NAME:18} | $AWK_BIN '{print tolower($0)}'`


TICKET_NUMBER=$(echo "$CURRENT_BRANCH" | $GREP_BIN -oE '^[A-Z]*-[0-9]*')
if [[ "$PATCH_VERSION" == "v1" ]] || [[ -z "$PATCH_VERSION" ]]
then
  PATCH_VERSION_SUFFIX=
else
  PATCH_VERSION_SUFFIX="_""$PATCH_VERSION"
fi
PATCH_FILE=`echo "$TICKET_NUMBER""_""$MAGENTO_VERSION""$PATCH_VERSION_SUFFIX"".patch"`


# 7. Create the patch file

$GIT_BIN diff -a -p --no-prefix "$COLLECT_REVISIONS_RANGE" > "$PATCH_FILE"

# Report results
CURRENT_DIR=`$PWD_BIN`
PATCH_FILE_PATH="$CURRENT_DIR"/"$PATCH_FILE"
if [ -f "${PATCH_FILE_PATH}" ]
then
  echo "Patch generated successfully: $PATCH_FILE. Location: $PATCH_FILE_PATH"
else
  echo Something went wrong when generating the patch.
fi
exit 0