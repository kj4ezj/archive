#!/bin/bash
set -eo pipefail
ARCHIVE_RSYNC_FLAGS_DEFAULT='-Ptv'
export GIT_BRANCH=''  # populated by make install
export GIT_ORIGIN=''  # populated by make install
export GIT_UNIXTS=''  # populated by make install
export GIT_VERSION='' # populated by make install

# run a command if dry-run is not set
function conditional-ee {
    EXIT_STATUS='0'
    if [[ -z "$ARCHIVE_DRY_RUN" ]]; then
        ee "$1" || EXIT_STATUS="$?"
    else
        echo "$ $1"
    fi
    return "$EXIT_STATUS"
}

# count PDF pages
function count-pages {
    PAGE_COUNT="$(pdfinfo "$1" | grep 'Pages' | awk '{print $2}')"
    echo "$PAGE_COUNT"
}

# exit success
function exit-success {
    if [[ -n "$ARCHIVE_DRY_RUN" ]]; then
        log '\e[1m\e[32mDone.\e[0m - \e[1m\e[33mDRY-RUN\e[0m'
    else
        log '\e[1m\e[32mDone.\e[0m'
    fi
    exit 0
}

# fail with a useful error
function fail {
    log "\e[1;31m$1\e[0m"
    log 'Documentation: https://github.com/kj4ezj/archive'
    log 'Exiting...'
    exit "${2:-1}"
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
    # commit timestamp
    if [[ -z "$GIT_UNIXTS" ]]; then
        GIT_UNIXTS="$(git log -1 --format='%ct')"
        export GIT_UNIXTS
    fi
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
        --dry-run
            Run through the process without performing write operations.

    -2, --dual
            Set the default view mode to "two-up (facing)" in "Document Reader."

    -h, --help, -?
            Print this help message and exit.

    -l, --license
            Print software license and exit.

        --list-multi-page-pdfs, --list-multi
            List all multi-page PDFs in the current directory, then exit.

        --merge-pdf, --merge
            Merge one series of PDFs into one.

    -m, --merge-pdfs, --merge-all-pdfs
            Merge all series of PDFs in the current directory, then exit.

    -p, --path
            Specify the subdirectory to archive to, appended to ARCHIVE_TARGET.

    -r, --rotation
            Set the default rotation to 0° in "Document Reader."

    -1, --single
            Set the default view mode to "single page (facing)" in "Document
            Reader" or xreader.

    -s, --split-multi-page-pdfs
            Split all multi-page PDFs in the current directory, then exit.

    -v, --version
            Print the script version with debug info and exit.

[VARIABLES] - configurable environment variables
    ARCHIVE_DRY_RUN
        If set, the script will not perform write operations.

    ARCHIVE_PATH_DEFAULT
        The default subdirectory to archive to, appended to ARCHIVE_TARGET.

    ARCHIVE_ROTATION
        The default rotation for "Document Reader" to use when opening files.

    ARCHIVE_RSYNC_FLAGS
        The rsync options to use when archiving files.

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
    echo "$GIT_REPO:$GIT_VERSION on $GIT_BRANCH from $(date -d "@$GIT_UNIXTS" '+%F %T %Z')"
    echo
    readlink -f "$0"
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        printf 'Running on %s %s with:\n' "$NAME" "$VERSION"
    elif [[ "$(uname)" == 'Darwin' ]]; then
        printf 'Running on %s %s with:\n' "$(sw_vers -productName)" "$(sw_vers -productVersion)"
    elif [[ "$(uname)" == 'Linux' ]]; then
        printf 'Running on Linux %s with:\n' "$(uname -r)"
    else
        echo 'Running on unidentified OS with:'
    fi
    printf '    '
    bash --version | head -1
    printf '    '
    grep --version | head -1
    RSYNC_VERSION="$(rsync -V 2>&1 || :)"
    printf '    '
    echo "$RSYNC_VERSION" | head -1
    printf '    '
    ssh -V 2>&1
    printf '    '
    pdfinfo -v 2>&1 | head -1
    echo
    git-uri
    echo 'Copyright © 2024 Zach Butler'
    echo 'MIT License'
    exit 0
}

# list file(s) on the server
function ls-remote {
    ee "ssh '$1' \"ls -la $2\"" 2>/dev/null || :
}

# merge all sets of PDFs in the current directory
function merge-multiple {
    for FILE in *_2.pdf; do
        merge-pdfs "${FILE/#.\//}"
    done
}

# given a series of PDFs, merge them into one
function merge-pdfs {
    # strip the suffix, if it exists
    BASE="${1%%_[0-9]*.pdf}"
    BASE="${BASE%.pdf}"
    BASE="${BASE/#.\//}"
    MERGED="${BASE}.pdf"
    PDFUNITE_CMD='pdfunite'
    # handle edge-case where example_1.pdf is named example.pdf
    if [[ -f "${BASE}.pdf" && ! -f "${BASE}_1.pdf" ]]; then
        conditional-ee "mv '${BASE}.pdf' '${BASE}_1.pdf'" || fail "ERROR: Failed to rename '${BASE}.pdf' to '${BASE}_1.pdf'! mv returned exit status '$?'." "$?"
        if [[ -n "$ARCHIVE_DRY_RUN" ]]; then
            PDFUNITE_CMD+=" '${BASE}_1.pdf'"
        fi
    elif [[ -f "${BASE}.pdf" && -f "${BASE}_1.pdf" ]]; then
        fail "ERROR: Both '${BASE}.pdf' and '${BASE}_1.pdf' exist! Rename or delete one of them." 15
    fi
    # find all parts in the series and verify the series is not empty
    mapfile -t PARTS < <(find . -maxdepth 1 -type f -iname "${BASE}_*.pdf" | sort -V | sed 's_./__')
    if [[ "${#PARTS[@]}" == '0' ]]; then
        fail "ERROR: No PDFs found in the series for '$1'!" 12
    fi
    # merge PDFs
    for PART in "${PARTS[@]}"; do
        log "Found part '$PART'."
        PDFUNITE_CMD+=" '$PART'"
    done
    PDFUNITE_CMD+=" '$MERGED'"
    conditional-ee "$PDFUNITE_CMD" || fail "ERROR: Failed to merge the PDF parts! pdfunite returned exit code '$?'." "$?"
    # remove the parts after merging
    for PART in "${PARTS[@]}"; do
        conditional-ee "rm '$PART'" || fail "ERROR: Failed to delete partial PDF '$PART' after merging! rm returned exit code '$?'." "$?"
    done
    log "\e[32mMerged PDFs into '$MERGED'.\e[0m"
}

# list all multi-page PDFs in the current directory, ignoring file extension case and ignoring subdirectories
function multi-page-pdf-util {
    FOUND_ANY_PDF_FILE='false'
    FOUND_MULTI_PAGE_PDF='false'
    while IFS= read -r FILE; do
        PDF_FILE="${FILE/#.\//}"
        FOUND_ANY_PDF_FILE='true'
        PAGE_COUNT="$(count-pages "$PDF_FILE")"
        # if it's a multi-page PDF, print the filename
        if (( PAGE_COUNT > 1 )); then
            FOUND_MULTI_PAGE_PDF='true'
            if [[ "$1" == 'list' ]]; then # list multi-page PDFs
                printf " %3d    %s\n" "$PAGE_COUNT" "$PDF_FILE"
            elif [[ "$1" == 'split' ]]; then # split multi-page PDFs
                conditional-ee "pdfseparate '$PDF_FILE' '${PDF_FILE%%.[pP][dD][fF]}_%d.pdf'" || fail "ERROR: Failed to split '$PDF_FILE'! pdfseparate returned exit code '$?'." "$?"
                conditional-ee "rm '$PDF_FILE'" || fail "ERROR: Failed to delete '$PDF_FILE' after splitting! rm returned exit code '$?'." "$?"
                log "\e[32mSplit '$PDF_FILE'.\e[0m"
            fi
        fi
    done < <(find . -maxdepth 1 -type f -iname '*.pdf' | sort)
    if [[ "$FOUND_ANY_PDF_FILE" == 'false' ]]; then
        fail 'No PDF files found in the current directory!' 13
    elif [[ "$FOUND_MULTI_PAGE_PDF" == 'false' ]]; then
        fail 'No multi-page PDFs found in the current directory!' 14
    fi
}

# pull a file from the server
function pull {
    if [[ -f "$2" ]]; then
        ee "rsync $ARCHIVE_RSYNC_FLAGS '$1' '${2%%.pdf}_$(date '+%s').pdf'" || fail "ERROR: Failed to pull '$1'! rsync returned exit code '$?'." "$?"
    else
        ee "rsync $ARCHIVE_RSYNC_FLAGS '$1' '$2'" || fail "ERROR: Failed to pull '$1'! rsync returned exit code '$?'." "$?"
    fi
}

# push a file to the server
function push {
    ee "rsync $ARCHIVE_RSYNC_FLAGS '$1' '$2'" || fail "ERROR: Failed to push '$1' to '$2'! rsync returned exit code '$?'." "$?"
}

# set xreader view mode to "two-up (facing)"
function set-view-dual {
    conditional-ee "ssh '$1' \"gio set '$2' metadata::xreader::dual-page-odd-left 1\"" || fail "ERROR: Failed to set view mode to 'two-up (facing)' on '$1:$2'! ssh or gio returned exit code '$?'." "$?"
}

# set xreader rotation
function set-view-rotation {
    conditional-ee "ssh '$1' \"gio set '$2' metadata::xreader::rotation $3\"" || fail "ERROR: Failed to set rotation to '$3' on '$1:$2'! ssh or gio returned exit code '$?'." "$?"
}

# set xreader view mode to "single page (facing)"
function set-view-single {
    conditional-ee "ssh '$1' \"gio set '$2' metadata::xreader::sizing_mode best-fit\"" || fail "ERROR: Failed to set view mode to 'single page (facing)' on '$1:$2'! ssh or gio returned exit code '$?'." "$?"
}

# main
git-metadata
# parse args
for (( i=1; i <= $#; i++)); do
    ARG="$(echo "${!i}" | tr -d '-')"
    if [[ "$(echo "$ARG" | grep -icP '^(dry-?run)$')" == '1' ]]; then
        export ARCHIVE_DRY_RUN='true'
    elif [[ "$(echo "$ARG" | grep -icP '^(h|help|[?])$')" == '1' ]]; then
        log-help-and-exit
    elif [[ "$(echo "$ARG" | grep -icP '^(l|license)$')" == '1' ]]; then
        log-license-and-exit
    elif [[ "$(echo "$ARG" | grep -icP '^(v|version)$')" == '1' ]]; then
        log-version-and-exit
    fi
done
log 'Begin.'
if [[ -n "$ARCHIVE_DRY_RUN" ]]; then
    log '\e[1m\e[33mDRY-RUN SET.\e[0m'
fi
SUB_DIR="$ARCHIVE_PATH_DEFAULT"
for (( i=1; i <= $#; i++)); do
    ARG="$(echo "${!i}" | tr -d '-')"
    if [[ "$(echo "$ARG" | grep -icP '^(dry-?run)$')" == '1' ]]; then
        export ARCHIVE_DRY_RUN='true'
    elif [[ "$(echo "$ARG" | grep -icP '^(2|dual*)$')" == '1' ]]; then
        ARCHIVE_VIEW_MODE='dual'
    elif [[ "$(echo "$ARG" | grep -icP '^(list-?multi-?(page)?-?(pdfs?)?)$')" == '1' ]]; then
        multi-page-pdf-util 'list'
        exit-success
    elif [[ "$(echo "$ARG" | grep -icP '^(merge-?(pdf)?)$')" == '1' ]]; then
        MERGE_SINGLE='true'
    elif [[ "$(echo "$ARG" | grep -icP '^(m|merge-?((all)?-?pdfs)?)$')" == '1' ]]; then
        merge-multiple
        exit-success
    elif [[ "$(echo "$ARG" | grep -icP '^(p|path)$')" == '1' ]]; then
        i="$(( i+1 ))"
        SUB_DIR="${!i}"
    elif [[ "$(echo "$ARG" | grep -icP '^(r|rotation)$')" == '1' ]]; then
        ARCHIVE_ROTATION='0'
    elif [[ "$(echo "$ARG" | grep -icP '^(1|single*)$')" == '1' ]]; then
        ARCHIVE_VIEW_MODE='single'
    elif [[ "$(echo "$ARG" | grep -icP '^(s|split|split-?(multi-?page-?)?pdfs?)$')" == '1' ]]; then
        multi-page-pdf-util 'list'
        multi-page-pdf-util 'split'
        exit-success
    else
        FILENAME="${!i}"
    fi
done
# run single PDF merge, if requested
if [[ "$MERGE_SINGLE" == 'true' ]]; then
    merge-pdfs "$FILENAME"
    exit-success
fi
# get SSH server
SERVER="$(echo "$ARCHIVE_TARGET" | cut -d ':' -f '1')"
# get target directory
REMOTE_DIR="$(echo "$ARCHIVE_TARGET" | cut -d ':' -f '2')/${SUB_DIR}"
REMOTE_PATH="${REMOTE_DIR}/${FILENAME}"
TARGET_DIR="${ARCHIVE_TARGET}/${SUB_DIR}"
TARGET_PATH="${TARGET_DIR}/${FILENAME}"
# parse rsync flags
if [[ -z "$ARCHIVE_RSYNC_FLAGS" ]]; then
    ARCHIVE_RSYNC_FLAGS="$ARCHIVE_RSYNC_FLAGS_DEFAULT"
fi
# rsync dry-run
if [[ -n "$ARCHIVE_DRY_RUN" ]]; then
    ARCHIVE_RSYNC_FLAGS="${ARCHIVE_RSYNC_FLAGS} -n"
fi
# test if the file exists
if file-exists "$SERVER" "$REMOTE_PATH"; then
    log "\e[1m\e[33mNOTICE: File '$FILENAME' already exists at '$TARGET_PATH'.\e[0m"
    ls-remote "$SERVER" "$REMOTE_PATH"
    log 'Pulling file...'
    pull "$TARGET_PATH" "$FILENAME"
    fail "File NOT archived!\e[0m\n\e[31mDecide what to keep and send it with this command:\e[0m\n$ rsync -Ptv '$FILENAME' '$TARGET_PATH'" 11
else
    log "File '$FILENAME' \e[32mdoes not\e[0m exist at '$TARGET_PATH'."
    # get date and date parts
    DATE="$(echo "$FILENAME" | grep -oP '^\d{4}-\d{2}-\d{2}')"
    DD="$(echo "$DATE" | grep -oP '\d{2}' | sed -n '4p')"
    MONTH="$(echo "$DATE" | grep -oP '^\d{4}-\d{2}')"
    RANGE="{$(( DD-1 )),$DD,$(( DD+1 ))}"
    YEAR="$(echo "$DATE" | grep -oP '^\d{4}')"
    # list neighbor files
    NEIGHBOR_FILES="$(ls-remote "$SERVER" "${REMOTE_DIR}/${MONTH}-${RANGE}*")"
    if [[ -n "$NEIGHBOR_FILES" ]]; then
        echo "$NEIGHBOR_FILES"
    else
        ls-remote "$SERVER" "${REMOTE_DIR}/${MONTH}*" || (ls-remote "$SERVER" "${REMOTE_DIR}/${YEAR}*" || :)
    fi
    # archive file
    log "Archiving '$FILENAME'..."
    push "$FILENAME" "$TARGET_PATH"
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
        log '\e[36mDefault view set to "two-up (facing)".\e[0m'
    else
        set-view-single "$SERVER" "$REMOTE_PATH"
        log '\e[34mDefault view set to "single page (facing)".\e[0m'
    fi
    # set "Document Reader" default rotation
    if [[ -n "$ARCHIVE_ROTATION" ]]; then
        log 'Setting default rotation for "Document Reader."'
        set-view-rotation "$SERVER" "$REMOTE_PATH" "$ARCHIVE_ROTATION"
        log "\e[35mDefault rotation set to $ROTATION°.\e[0m"
    fi
    # pause for user, then delete local file
    printf "Press [Enter] to delete the local copy of '%s'..." "$FILENAME"
    [[ -n "$ARCHIVE_DRY_RUN" ]] && printf ' \e[1m\e[33m(DRY-RUN)\e[0m'
    read -rp ' '
    conditional-ee "rm '$FILENAME'" || fail "ERROR: Failed to delete '$FILENAME'! rm returned exit code '$?'." "$?"
fi
exit-success

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
