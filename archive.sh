#!/bin/bash
set -eo pipefail
export GIT_BRANCH=''  # populated by make install
export GIT_ORIGIN=''  # populated by make install
export GIT_VERSION='' # populated by make install

# count PDF pages
function count-pages {
    PAGE_COUNT="$(pdfinfo "$1" | grep 'Pages' | awk '{print $2}')"
    return "$PAGE_COUNT"
}

# test if a file exists
function file-exists {
    if ee "ssh '$1' \"[[ -f '$2' ]]\""; then
        return 0
    else
        return 1
    fi
}

# populate the git branch, origin, and version
function git-metadata {
    # branch
    if [[ -z "$GIT_BRANCH" ]]; then
        GIT_BRANCH="$(git branch --show-current)"
        export GIT_BRANCH
    fi
    # remote origin
    if [[ -z "$GIT_ORIGIN" ]]; then
        GIT_ORIGIN="$(git remote get-url origin)"
    fi
    ORIGIN="$(echo "$GIT_ORIGIN" | sed 's/[.]git//' | sed -E 's_(git@|https?://)__' | tr ':' '/')"
    GIT_REPO="${ORIGIN#*/}"
    export GIT_ORIGIN GIT_REPO
    # version string
    if [[ -z "$GIT_VERSION" ]]; then
        SCRIPT_PATH="$(readlink -f "$0")"
        SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
        pushd "$SCRIPT_DIR" >/dev/null
        GIT_VERSION="$(git describe --tags --exact-match 2>/dev/null || git rev-parse HEAD)"
        export GIT_VERSION
        popd >/dev/null
    fi
}

# return the git uri
function git-uri {
    ORIGIN="$(echo "$GIT_ORIGIN" | sed 's/[.]git//' | sed -E 's_(git@|https?://)__' | tr ':' '/')"
    echo "https://$ORIGIN/tree/$GIT_VERSION"
}

# prepend timestamp and script name to log lines
function log {
    printf "\e[0;30m%s ${0##*/} -\e[0m $*\n" "$(date '+%F %T %Z')"
}

# print help and exit
function log-help-and-exit {
    # shellcheck disable=SC2016
    echo '
                                ###########
                                # archive #
                                ###########

Both rsync and scp will overwrite files that exist in the destination. The
archive.sh BASH script wraps `rsync` to test if files exist before sending them
to the destination, and provides ancillary services useful for digitizing
documents.

$ archive [OPTIONS] [FILENAME]

[OPTIONS] - command-line arguments to change behavior
    -1, --single
        Set the default view mode to "single page (facing)" in "Document Reader."

    -2, --dual
        Set the default view mode to "two-up (facing)" in "Document Reader."

    -h, --help, -?
        Print this help message and exit.

    -l, --license
        Print software license and exit.

    -p, --path
        Specify the subdirectory to archive to, appended to ARCHIVE_TARGET.

    -r, --rotation
        Set the default rotation to 0° in "Document Reader."

    -v, --version
        Print the script version with debug info and exit.

[VARIABLES] - configurable environment variables
    ARCHIVE_PATH_DEFAULT
        The default subdirectory to archive to, appended to ARCHIVE_TARGET.

    ARCHIVE_ROTATION
        The default rotation for "Document Reader" to use when opening files.

    ARCHIVE_TARGET
        The destination directory for your files to be archived.

    ARCHIVE_VIEW_MODE
        The default view mode for "Document Reader" to use when opening files.

[NOTES]
Arguments take precedence over environment variables.

[DOCUMENTATION]'
    README_URI="$(git-uri | tr -d '\n\r')"
    echo "$README_URI/README.md"
    echo
    echo 'Copyright © 2024 Zach Butler'
    echo 'MIT License'
    exit 0
}

# print the license and exit
function log-license-and-exit {
    awk '/^# MIT License/,0 { print }' "$0" | sed -E 's/# ?//'
    exit 0
}

# print script version and other info
function log-version-and-exit {
    echo "$GIT_REPO:$GIT_VERSION on $GIT_BRANCH"
    echo
    readlink -f "$0"
    git-uri
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        printf 'Running on %s %s with ' "$NAME" "$VERSION"
    elif [[ "$(uname)" == 'Darwin' ]]; then
        printf 'Running on %s %s with ' "$(sw_vers -productName)" "$(sw_vers -productVersion)"
    elif [[ "$(uname)" == 'Linux' ]]; then
        printf 'Running on Linux %s with ' "$(uname -r)"
    else
        echo 'Running on unidentified OS with '
    fi
    bash --version | head -1
    echo 'Copyright © 2024 Zach Butler'
    echo 'MIT License'
    exit 0
}

# list file(s) on the server
function ls-remote {
    ee "ssh '$1' \"ls -la $2\"" || return "$?"
}

# pull a file from the server
function pull {
    if [[ -f "$2" ]]; then
        ee "rsync -Ptv '$1' '$2_$(date '+%s')'"
    else
        ee "rsync -Ptv '$1' '$2'"
    fi
}

# set xreader view mode to "two-up (facing)"
function set-view-dual {
    ee "ssh '$1' \"gio set '$2' metadata::xreader::dual-page-odd-left 1\""
}

# set xreader rotation
function set-view-rotation {
    ee "ssh '$1' \"gio set '$2' metadata::xreader::rotation $3\""
}

# set xreader view mode to "single page (facing)"
function set-view-single {
    ee "ssh '$1' \"gio set '$2' metadata::xreader::sizing_mode best-fit\""
}

# main
git-metadata
SUB_DIR="$ARCHIVE_PATH_DEFAULT"
# parse args
for (( i=1; i <= $#; i++)); do
    ARG="$(echo "${!i}" | tr -d '-')"
    if [[ "$(echo "$ARG" | grep -icP '^(1|single*)$')" == '1' ]]; then
        ARCHIVE_VIEW_MODE='single'
    elif [[ "$(echo "$ARG" | grep -icP '^(2|dual*)$')" == '1' ]]; then
        ARCHIVE_VIEW_MODE='dual'
    elif [[ "$(echo "$ARG" | grep -icP '^(h|help|[?])$')" == '1' ]]; then
        log-help-and-exit
    elif [[ "$(echo "$ARG" | grep -icP '^(license)$')" == '1' ]]; then
        log-license-and-exit
    elif [[ "$(echo "$ARG" | grep -icP '^(p|path)$')" == '1' ]]; then
        i="$(( i+1 ))"
        SUB_DIR="${!i}"
    elif [[ "$(echo "$ARG" | grep -icP '^(r|rotation)$')" == '1' ]]; then
        ARCHIVE_ROTATION='0'
    elif [[ "$(echo "$ARG" | grep -icP '^(v|version)$')" == '1' ]]; then
        log-version-and-exit
    else
        FILENAME="${!i}"
    fi
done
log 'Begin.'
# get SSH server
SERVER="$(echo "$ARCHIVE_TARGET" | cut -d ':' -f '1')"
# get target directory
REMOTE_DIR="$(echo "$ARCHIVE_TARGET" | cut -d ':' -f '2')/${SUB_DIR}"
REMOTE_PATH="${REMOTE_DIR}/${FILENAME}"
TARGET_DIR="${ARCHIVE_TARGET}/${SUB_DIR}"
TARGET_PATH="${TARGET_DIR}/${FILENAME}"
# test if the file exists
if file-exists "$SERVER" "$REMOTE_PATH"; then
    log "File '$FILENAME' exists at '$TARGET_PATH'."
    ls-remote "$SERVER" "$REMOTE_PATH"
    log 'Pulling file...'
    pull "$TARGET_PATH" "$FILENAME"
    log 'File NOT archived! Decide what to keep and send it with this command:'
    log "$ rsync -Ptv '$FILENAME' '$TARGET_PATH'"
else
    log "File '$FILENAME' does not exist at '$TARGET_PATH'."
    # get date and date parts
    DATE="$(echo "$FILENAME" | grep -oP '^\d{4}-\d{2}-\d{2}')"
    DD="$(echo "$DATE" | grep -oP '\d{2}' | sed -n '4p')"
    MONTH="$(echo "$DATE" | grep -oP '^\d{4}-\d{2}')"
    RANGE="{$(( DD-1 )),$DD,$(( DD+1 ))}"
    YEAR="$(echo "$DATE" | grep -oP '^\d{4}')"
    # list neighbor files
    ls-remote "$SERVER" "${REMOTE_DIR}/${MONTH}-${RANGE}*" || ls-remote "$SERVER" "${REMOTE_DIR}/${MONTH}*" || ls-remote "$SERVER" "${REMOTE_DIR}/${YEAR}*"
    # archive file
    log "Archiving '$FILENAME'..."
    ee "rsync -Ptv '$FILENAME' '$TARGET_PATH'"
    # set "Document Reader" default view mode
    log 'Setting default view mode for "Document Reader."'
    if [[ -z "$ARCHIVE_VIEW_MODE" ]]; then
        PAGE_COUNT="$(count-pages "$FILENAME")"
        log "Found $PAGE_COUNT page PDF."
        if (( PAGE_COUNT > 1 )); then
            ARCHIVE_VIEW_MODE='dual'
        else
            ARCHIVE_VIEW_MODE='single'
        fi
    fi
    if [[ "$ARCHIVE_VIEW_MODE" == 'dual' ]]; then
        set-view-dual "$SERVER" "$REMOTE_PATH"
        log 'Default view set to "two-up (facing)".'
    else
        set-view-single "$SERVER" "$REMOTE_PATH"
        log 'Default view set to "single page (facing)".'
    fi
    # set "Document Reader" default rotation
    if [[ -n "$ARCHIVE_ROTATION" ]]; then
        log 'Setting default rotation for "Document Reader."'
        set-view-rotation "$SERVER" "$REMOTE_PATH" "$ARCHIVE_ROTATION"
        log "Default rotation set to $ROTATION°."
    fi
    # pause for user, then delete local file
    read -rp "Press [Enter] to delete the local copy of '$FILENAME'..."
    rm "$FILENAME"
fi
log 'Done.'

# https://github.com/kj4ezj/archive

# MIT License
#
# Copyright (c) 2024 Zach Butler
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
