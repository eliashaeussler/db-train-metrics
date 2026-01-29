#!/usr/bin/env bash
# shellcheck disable=SC2155
set -e

RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
CYAN="\033[1;36m"
GRAY="\033[0;90m"
NC="\033[0m"

readonly grafanaUrl="http://localhost:9772"
readonly prometheusUrl="http://localhost:9773"

build=0
debug=0
follow=0
logs=0
open=0
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
    echo -e "  ${CYAN}Start Docker containers and open Grafana dashboard.${NC}"
    echo
    echo -e "Usage:"
    echo -e "  ${CYAN}$0${NC} [<flags>]"
    echo
    echo -e "Flags:"
    echo -e "  ${GREEN}-b, --build${NC}     Rebuild local Docker images"
    echo -e "  ${GREEN}-d, --debug${NC}     Display more information when running this script"
    echo -e "  ${GREEN}-f, --follow${NC}    Keep containers running as long as the script runs"
    echo -e "  ${GREEN}-h, --help${NC}      Show this help"
    echo -e "  ${GREEN}-l, --logs${NC}      Follow container logs once containers are running"
    echo -e "  ${GREEN}-o, --open${NC}      Open the Grafana dashboard in your browser"
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
    -b|--build)
        build=1
        shift
        ;;
    -d|--debug)
        debug=1
        shift
        ;;
    -f|--follow)
        follow=1
        shift
        ;;
    -h|--help)
        _usage
        exit 0
        ;;
    -l|--logs)
        logs=1
        shift
        ;;
    -o|--open)
        open=1
        shift
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

function check_requirements() {
    _progress "Checking system requirements"

    if ! command -v docker >/dev/null 2>&1; then
        _failed
        _error "docker is required, but not installed on your system."
    fi

    if ! docker compose >/dev/null 2>&1; then
        _failed
        _error "docker compose is required, but not installed on your system."
    fi

    _done
}

function prune_volumes() {
    _progress "Pruning Docker volumes"

    local command
    local commands=("docker compose down --remove-orphans" "rm -rfv data/grafana data/prometheus")

    if [ "$debug" -eq 1 ]; then
        for command in "${commands[@]}"; do
            $command
        done
    else
        for command in "${commands[@]}"; do
            if ! $command >/dev/null 2>&1; then
                _failed
                _error "An error occurred while pruning Docker volumes. Run this script again with --debug flag for more details."
            fi
        done

        _done
    fi
}

function build_image() {
    _progress "Building Docker image"

    local command="docker compose build"

    if [ "$debug" -eq 1 ]; then
        $command
    else
        if ! $command >/dev/null 2>&1; then
            _failed
            _error "An error occurred while building Docker image. Run this script again with --debug flag for more details."
        fi

        _done
    fi
}

function start_containers() {
    _progress "Starting Docker containers"

    local command="docker compose up -d"

    if [ "$debug" -eq 1 ]; then
        $command
    else
        if ! $command >/dev/null 2>&1; then
            _failed
            _error "Could not start Docker containers. Run this script again with --debug flag for more details."
        fi

        _done
    fi
}

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

function open_grafana() {
    _progress "Opening Grafana in your browser"

    local command

    if command -v xdg-open >/dev/null 2>&1; then
        command="xdg-open ${grafanaUrl}/?kiosk"
    else
        command="open ${grafanaUrl}/?kiosk"
    fi

    # Make sure Grafana is started
    sleep 1

    if [ "$debug" -eq 1 ]; then
        $command
    else
        if ! $command >/dev/null 2>&1; then
            _failed
        else
            _done
        fi
    fi
}

function show_connection() {
    printf '\n'
    printf '+----------------------+------------------------------------------+\n'
    printf '| %-20s | %-40s |\n' "Service" "URL"
    printf '+----------------------+------------------------------------------+\n'
    printf '| %-20s | %-40s |\n' "Grafana" "${grafanaUrl}"
    printf '| %-20s | %-40s |\n' "Prometheus" "${prometheusUrl}"
    printf '+----------------------+------------------------------------------+\n'
    printf '\n'
}

function cleanup_and_exit() {
    echo
    echo -e "${YELLOW}Caught interrupt, shutting down containers.${NC}"
    stop_containers
    exit 0
}

function finalize() {
    if [ "$follow" -eq 1 ]; then
        trap cleanup_and_exit INT TERM
        echo -e "${GRAY}Follow mode enabled. Press Ctrl+C to stop containers and exit.${NC}"

        if [ "$logs" -eq 0 ]; then
            tail -f /dev/null
        fi
    else
        echo -e "${GREEN}All Docker containers are running.${NC}"
        echo -e "Run ${CYAN}./stop.sh${NC} to stop containers."
        echo -e "${GRAY}You can also run this script with ${YELLOW}--follow${GRAY} to keep containers open while the script is running.${NC}"
    fi

    if [ "$logs" -eq 1 ]; then
        echo
        docker compose logs -f
    fi
}

check_requirements

if [ "$prune" -eq 1 ]; then
    prune_volumes
fi

if [ "$build" -eq 1 ]; then
    build_image
fi

start_containers

if [ "$open" -eq 1 ]; then
    open_grafana
fi

show_connection
finalize
