#!/bin/bash
set -eo pipefail
echo "Begin - ${0##*/}"
source ./deps/bin/ee

# lint project
printf '\e[1;35m===== Lint archive.sh =====\e[0m\n'
ee bashate -i E006 archive.sh
ee shellcheck -e SC1091 -f gcc archive.sh

echo "Done. - ${0##*/}"
