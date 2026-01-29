# DB train metrics

This repository allows to visualize data of the current trip when
travelling on board of a DB train. It visualizes speed and delay
and displays information about the current train and next station.

![Screenshot](docs/screenshot.png)

## Requirements

> [!NOTE]
> You must be connected to a `WIFIonICE` network in order for this
> repository to work since it fetches all relevant information from
> DB Onboard APIs.

* [Docker](https://docs.docker.com/get-docker/)
* [Docker Compose](https://docs.docker.com/compose/install/)
* Connection to [`WIFIonICE` network](https://int.bahn.de/en/trains/wifi)

## Usage

> [!TIP]
> Since bandwidth on trains is limited, it is recommended to pull all
> necessary Docker images prior to boarding the train. Just clone the
> repository and run [`build.sh`](#build-docker-images).

### Quickstart

1. Clone the repository
2. Run `./start.sh --open --follow`

### Start Docker containers

Use the [`start.sh`](start.sh) script to start Docker containers and
open the Grafana dashboard in your browser.

```bash
$ ./start.sh [<flags>]
```

Flags:

```
-b, --build     Rebuild local Docker images
-d, --debug     Display more information when running this script
-f, --follow    Keep containers running as long as the script runs
-h, --help      Show this help
-o, --open      Open the Grafana dashboard in your browser
-p, --prune     Prune existing Docker volumes to reset persisted data
-v, --version   Print the current version of this script
```

_You can also do this manually by running `docker compose up`._

### Stop Docker containers

Use the [`stop.sh`](stop.sh) script to stop running Docker containers.

```bash
$ ./stop.sh [<flags>]
```

Flags:

```
-d, --debug     Display more information when running this command
-h, --help      Show this help
-p, --prune     Prune existing Docker volumes to reset persisted data
-v, --version   Print the current version of this script
```

_You can also do this manually by running `docker compose down`._

### Build Docker images

Use the [`build.sh`](build.sh) script to (re)build Docker images.

```bash
$ ./build.sh [<flags>]
```

Flags:

```
-d, --debug     Display more information when running this script
-h, --help      Show this help
-v, --version   Print the current version of this script
```

_You can also do this manually by running `docker compose build --pull`._

## Troubleshooting

If your dashboard doesn't receive any data make sure that you are
really connected to the ICE Wifi and that you can access
[iceportal.de](https://iceportal.de) in  your browser.

You can also check for connection problems by running
`docker compose logs -f bridge`. The logs should show failed requests
to fetch JSON from <https://iceportal.de/api1/rs/status>
and <https://iceportal.de/api1/rs/tripInfo/trip>.

Unfortunately, the connection to the DB Onboard API is not very stable
and may not always work.

## Stack

* [Prometheus](https://prometheus.io/) as data source
* [Grafana](https://grafana.com/) for visualization
* [Python](https://www.python.org/) script as bridge between DB Onboard API and Prometheus
* [Docker](https://www.docker.com/) for containerization
