#!/usr/bin/env bash
#shellcheck disable=SC2153
# Shellcheck ignores use of unknown environment variables

### Requirements
### ----------------------------------------
### jq
### ----------------------------------------


### Parsing command-line arguments
if [[ "$GITHUB_ACTION" = "true" || "$IS_DOCKER" = "true" ]]; then
    #shellcheck disable=SC1091
    source "/code/bargs.sh" "$@"
else
    #shellcheck disable=SC1090
    source "${PWD}/$(dirname "${BASH_SOURCE[0]}")/bargs.sh" "$@"
fi

set -e
set -o pipefail


### Functions
msg_error(){
    local msg="$1"
    echo -e "[ERROR] $(date) :: $msg"
    export DEBUG=1
    exit 1
}


msg_log(){
    local msg="$1"
    echo -e "[LOG] $(date) :: $msg"
}


msg_debug(){
    local msg="$1"
    if [[ "$_CONFIGMAP_DEBUG" = "true" ]]; then
        echo -e "[DBG] $(date) :: $msg"
    fi
}


set_step_output(){
    local output_name="$1"
    local output_value="$2"
    msg_debug "Setting the output ${output_name}=${output_value}"
    echo "::set-output name=${output_name}::${output_value}"
}


validate_values(){
    declare -a values=()
    #shellcheck disable=SC2206
    values=($@)
    for item in "${values[@]}"; do
        if [[ "$item" = "null" ]]; then
            msg_error "Value not allowed, check inputs\n$(env | grep "CONFIGMAP_.*=null")"
        fi
    done
}


main(){
    local configmap_map="$_CONFIGMAP_MAP"
    local configmap_key="$_CONFIGMAP_KEY"
    local configmap_key_exists=""
    local configmap_default_key_name="$_CONFIGMAP_DEFAULT_KEY_NAME"    
    local configmap_default_key_name_exists=""
    local selected_key=""

    if [[ -n "$configmap_default_key_name" ]]; then
        configmap_default_key_name_exists="$(echo ${configmap_map} | jq .${configmap_default_key_name})"
        msg_debug "configmap_default_key_name_exists=${configmap_default_key_name_exists}"
        [[ -n "$configmap_default_key_name_exists" && "$configmap_default_key_name_exists" != "null" ]] && selected_key="$configmap_default_key_name"
        msg_debug "selected_key=${selected_key}"
    fi

    if [[ -n "$configmap_key" ]]; then
        configmap_key_exists="$(echo ${configmap_map} | jq .${configmap_key})"
        msg_debug "configmap_key_exists=${configmap_key_exists}"
        [[ -n "$configmap_key_exists" && "$configmap_key_exists" != "null" ]] && selected_key="$configmap_key"
        msg_debug "selected_key=${selected_key}"
    fi

    if [[ -n "$selected_key" && "$selected_key" != "null" ]]; then
        msg_log "Final selected_key=${selected_key}"
    else
        msg_error "Failed to find the selected key '${selected_key}' in configmap_map"
    fi

    msg_debug "Print configmap_map to JSON"
    msg_debug "$(echo ""; echo ${configmap_map} | jq -cr ".${selected_key} | tojson")"

    set_step_output "CONFIGMAP_MAP" "$(echo ${configmap_map} | jq -cr ".${selected_key} | tojson")"
    set_step_output "CONFIGMAP_SELECTED_KEY" "$selected_key"

    msg_log "Completed successfully"
}


### Global Variables
_CONFIGMAP_MAP="$CONFIGMAP_MAP"
_CONFIGMAP_KEY="$CONFIGMAP_KEY"
_CONFIGMAP_DEFAULT_KEY_NAME="${CONFIGMAP_DEFAULT_KEY_NAME:-"default"}"
_CONFIGMAP_DEBUG="${CONFIGMAP_DEBUG:-"false"}"

### Main
main