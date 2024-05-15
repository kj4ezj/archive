#!/bin/bash
set -eo pipefail
export GIT_BRANCH=''  # populated by make install
export GIT_ORIGIN=''  # populated by make install
export GIT_VERSION='' # populated by make install

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

$ archive [OPTIONS]

[OPTIONS] - command-line arguments to change behavior
    -h, --help, -?
        Print this help message and exit.

    -l, --license
        Print software license and exit.

    -v, --version
        Print the script version with debug info and exit.

[VARIABLES] - configurable environment variables

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

# main
git-metadata
# parse args
for (( i=1; i <= $#; i++)); do
    ARG="$(echo "${!i}" | tr -d '-')"
    if [[ "$(echo "$ARG" | grep -icP '^(h|help|[?])$')" == '1' ]]; then
        log-help-and-exit
    elif [[ "$(echo "$ARG" | grep -icP '^(license)$')" == '1' ]]; then
        log-license-and-exit
    elif [[ "$(echo "$ARG" | grep -icP '^(v|version)$')" == '1' ]]; then
        log-version-and-exit
    fi
done
log 'Begin.'
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
