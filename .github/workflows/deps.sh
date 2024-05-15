#!/bin/bash
set -eo pipefail
echo "Begin - ${0##*/}"

function ee {  # we can't use ee from the deps folder until bpkg is installed and initialized
    echo "$ $*"
    eval "$@"
}

# apt
ee sudo apt-get update -qq
ee sudo apt-get install -yqq \
    curl \
    git \
    make \
    python3-bashate \
    shellcheck \
        '>/dev/null'
# bpkg
ee curl -fsSL 'https://raw.githubusercontent.com/bpkg/bpkg/master/setup.sh' -o bpkg-setup.sh
ee chmod +x bpkg-setup.sh
ee sudo ./bpkg-setup.sh

# versions
source /etc/os-release || :
echo "$NAME $VERSION" || :
ee uname -r || :
ee bash --version || :
ee "apt-cache show python3-bashate | grep -i version | cut -d ' ' -f 2" || :
ee bpkg --version || :
ee curl --version || :
ee git --version || :
ee make --version || :
ee shellcheck --version || :

echo "Done. - ${0##*/}"
