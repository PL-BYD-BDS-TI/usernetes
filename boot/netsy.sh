#!/bin/bash
export U7S_BASE_DIR=$(realpath $(dirname $0)/..)
source $U7S_BASE_DIR/common/common.inc.sh

# TODO env vars for netsy - node-level config

exec netsy \
	--config=$XDG_CONFIG_HOME/usernetes/netsy/config.jsonc \
	$@
