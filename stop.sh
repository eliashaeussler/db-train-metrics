#!/usr/bin/env bash
# shellcheck disable=SC2155
set -e

RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
CYAN="\033[1;36m"
GRAY="\033[0;90m"
NC="\033[0m"

debug=0
prune=0

function _get_version() {
    local version="$(git describe --tags --abbrev=0 HEAD 2>/dev/null || git rev-parse --short HEAD)"

    echo -e "${RED}db${NC}-train-metrics ${version}"
    echo -e "${GRAY}by Elias Häußler and contributors${NC}"
}

function _display_links() {
    echo -e "${YELLOW}Found an issue?${NC}"
    echo -e "Report: https://github.com/eliashaeussler/db-train-metrics/issues"
    echo -e "${YELLOW}Do you like it?${NC}"
    echo -e "Donate: https://github.com/sponsors/eliashaeussler"
}

function _usage() {
    local version="$(_get_version)"

    echo
    echo -e "$version"
    echo
    echo -e "Description:"
    echo -e "  ${CYAN}Stop currently running Docker containers.${NC}"
    echo
    echo -e "Usage:"
    echo -e "  ${CYAN}$0${NC} [<flags>]"
    echo
    echo -e "Flags:"
    echo -e "  ${GREEN}-d, --debug${NC}     Display more information when running this command"
    echo -e "  ${GREEN}-h, --help${NC}      Show this help"
    echo -e "  ${GREEN}-p, --prune${NC}     Prune existing Docker volumes to reset persisted data"
    echo -e "  ${GREEN}-v, --version${NC}   Print the current version of this script"
    echo
}

function _error() {
    local message="$1"
    local exitCode="${2:-1}"

    >&2 echo -e "${RED}${message}${NC}"
    exit "$exitCode"
}

function _progress() {
    local message="$1"

    if [ "$debug" -eq 1 ]; then
        echo -e "${CYAN}▶ ${message}...${NC}"
    else
        printf "%s... " "$message"
    fi
}

function _done() {
    if [ "$debug" -eq 0 ]; then
        echo -e "${GREEN}Done${NC}"
    fi
}

function _failed() {
    if [ "$debug" -eq 0 ]; then
        echo -e "${RED}Failed${NC}"
    fi
}

while [ $# -gt 0 ]; do
    case "$1" in
    -d|--debug)
        debug=1
        shift
        ;;
    -h|--help)
        _usage
        exit 0
        ;;
    -p|--prune)
        prune=1
        shift
        ;;
    -v|--version)
        echo
        _get_version
        echo
        _display_links
        echo
        exit 0
        ;;
    -*)
        _usage
        _error "Unknown option: $1" 2
        ;;
    *)
        _usage
        _error "Unknown argument: $1" 2
        ;;
    esac
done

function stop_containers() {
    _progress "Stopping Docker containers"

    local command="docker compose down --remove-orphans"

    if [ "$debug" -eq 1 ]; then
        $command
    else
        if ! $command >/dev/null 2>&1; then
            _failed
            _error "Could not stop Docker containers. Run this script again with --debug flag for more details."
        fi

        _done
    fi
}

function prune_volumes() {
    _progress "Pruning Docker volumes"

    local command="rm -rfv data/grafana data/prometheus"

    if [ "$debug" -eq 1 ]; then
        $command
    else
        if ! $command >/dev/null 2>&1; then
            _failed
            _error "An error occurred while pruning Docker volumes. Run this script again with --debug flag for more details."
        fi

        _done
    fi
}

function finalize() {
    echo
    echo -e "${GREEN}Docker containers have been stopped.${NC}"
    echo -e "Run ${CYAN}./start.sh${NC} to restart them and open the Grafana dashboard."
}

stop_containers

if [ "$prune" -eq 1 ]; then
    prune_volumes
fi

finalize
