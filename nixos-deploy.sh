#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(dirname "$0")"
SCRIPT_NAME=$(basename $0)

function showSyntax() {
cat <<EOF
$SCRIPT_NAME [-f hosts_file] [--fast] [--no-ssh-multiplexing] [BUILD_OPTIONS...] -h host action
EOF
}

# Parse the command line.
extraBuildFlags=()
extraInstantiateFlags=()
arguments=()
hostsFile="default.nix"
hosts=()
action=
fast="false"
sshMultiplexing=1

while [ "$#" -gt 0 ]; do
    i="$1"; shift 1
    case "$i" in
        --help)
            showSyntax
            exit 0
            ;;
        --hosts-file|-f)
            hostsFile="$1"
            shift 1
            ;;
        --host|--hosts|-h)
            hosts+=("$1")
            shift 1
            ;;
        --fast)
            fast="true"
            ;;
        --no-ssh-multiplexing)
            sshMultiplexing=
            ;;
        --max-jobs|-j|--cores|-I|--remote-path)
            j="$1"; shift 1
            extraBuildFlags+=("$i" "$j")
            ;;
        --keep-failed|-K|--keep-going|-k|--verbose|-v|-vv|-vvv|-vvvv|-vvvvv|--fallback|--repair|-Q|-j*)
            extraBuildFlags+=("$i")
            ;;
        --show-trace)
            extraInstantiateFlags+=("$i")
            extraBuildFlags+=("$i")
            ;;
        --option)
            j="$1"; shift 1
            k="$1"; shift 1
            extraBuildFlags+=("$i" "$j" "$k")
            ;;
        --*)
            echo "$SCRIPT_NAME: unknown option '$i'"
            exit 1
            ;;
        *)
            arguments+=("$i")
            ;;
    esac
done

if [ ${#arguments[@]} -ne 1 ]; then
    showSyntax
    exit 1
fi

if [ ${#hosts[@]} -eq 0 ]; then
    showSyntax
    exit 1
fi

action="${arguments[0]}"

case "$action" in
    switch|boot|test|build|dry-build|dry-activate|build-image|install)
        ;;
    *)
        echo "$SCRIPT_NAME: unknown action '$action'"
        exit 1
        ;;
esac

if [[ "$hostsFile" != /* ]]; then
    hostsFile="$PWD/$hostsFile"
fi

if [ ! -f "$hostsFile" ]; then
    echo "$SCRIPT_NAME: file '$hostsFile' does not exist"
    exit 1
fi

if [[ "$hosts" == "all" ]]; then
    hosts=();
fi

hosts_list="$(python -c 'import json, sys; print(json.dumps([s for arg in sys.argv[1:] for s in arg.split(",")]))' "${hosts[@]}")"

export BASE_CONFIG_EXPR="(import $SCRIPT_DIR/nixos-config.nix \"$hostsFile\")"
export extraInstantiateFlags extraBuildFlags sshMultiplexing
$(nix-build --expr "$BASE_CONFIG_EXPR.stage1 \"$action\" ''$hosts_list'' $fast" "${extraInstantiateFlags[@]}")
