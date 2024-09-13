#!/usr/bin/env python

"""
Collect DB train metrics and export them as Prometheus data.
"""

import json
import logging
import sys
import time
import urllib
from urllib.request import urlopen
from geopy.distance import geodesic
from prometheus_client import start_http_server
from prometheus_client.core import GaugeMetricFamily, REGISTRY

class DbTrainMetricsCollector():
    """
    Collect and export DB train metrics.
    """

    STATUS_URL = "https://iceportal.de/api1/rs/status"
    TRIP_URL = "https://iceportal.de/api1/rs/tripInfo/trip"

    def __init__(self, logger):
        self.logger = logger

    def collect(self):
        """
        Collect DB train metrics from DB Onboard API.
        """

        speed_metric = GaugeMetricFamily('train_speed', 'Speed in km/h of the current train')
        trip_metric = GaugeMetricFamily(
            'train_trip',
            'Delay in minutes of the current trip',
            labels=['train', 'next_station']
        )
        distance_metric = GaugeMetricFamily(
            'train_distance',
            'Distance in km until next station of the current trip'
        )

        # Collect speed and delay information
        speed, current_location = self.collect_status()
        train, next_station, delay, next_station_location = self.collect_trip()

        # Handle speed metric
        if speed is not None:
            speed_metric.add_metric([], speed)
            self.logger.debug('Extracted train speed from JSON response: %.2f', speed)
        else:
            speed_metric.add_metric([], 0.0)

        # Handle trip metric
        if train is not None and next_station is not None and delay is not None:
            trip_metric.add_metric([train, next_station], delay)
            self.logger.debug('Extracted train from JSON response: %s', train)
            self.logger.debug('Extracted next station from JSON response: %s', next_station)
            self.logger.debug('Extracted delay from JSON response: %d', delay)
        else:
            trip_metric.add_metric(['Unknown', 'Unknown'], 0)

        # Handle distance metric
        if current_location is not None and next_station_location is not None:
            distance = self.calculate_distance(current_location, next_station_location)
            distance_metric.add_metric([], distance)
            self.logger.debug('Extracted current location from JSON response: %s', current_location)
            self.logger.debug(
                'Extracted next station location from JSON response: %s',
                next_station_location
            )
            self.logger.debug('Calculated distance: %.2f', distance)
        else:
            distance_metric.add_metric([], 0)

        yield speed_metric
        yield trip_metric
        yield distance_metric

    def collect_status(self):
        """
        Collect status metrics from DB onboard status API.
        """

        try:
            with urlopen(self.STATUS_URL, timeout=20) as res:
                status_response = json.load(res)
        except urllib.error.URLError as error:
            self.logger.error('Error while fetching JSON from %s: %s', self.STATUS_URL, str(error))
            return None, None
        except json.decoder.JSONDecodeError as error:
            self.logger.error('Error while decoding JSON from %s: %s', self.STATUS_URL, str(error))
            return None, None

        speed = status_response.get('speed', 0.0)
        latitude = status_response.get('latitude')
        longitude = status_response.get('longitude')

        if latitude is None or longitude is None:
            coordinates = None
        else:
            coordinates = (latitude, longitude)

        return speed, coordinates

    def collect_trip(self): # pylint: disable=too-many-locals
        """
        Collect trip metrics from DB onboard trip API.
        """

        try:
            with urlopen(self.TRIP_URL, timeout=20) as res:
                trip_response = json.load(res)
        except urllib.error.URLError as error:
            self.logger.error('Error while fetching JSON from %s: %s', self.TRIP_URL, str(error))
            return None, None, None, None
        except json.decoder.JSONDecodeError as error:
            self.logger.error('Error while decoding JSON from %s: %s', self.TRIP_URL, str(error))
            return None, None, None, None

        # Fetch train, next station and all stops
        trip = trip_response.get('trip', {})
        train = str(trip.get('trainType', '') + ' ' + trip.get('vzn', '')).strip()
        next_station = trip.get('stopInfo', {}).get('actualNext')
        all_stops = trip.get('stops', [])

        self.logger.debug('Extracted next station from JSON response: %s', next_station)

        # Early return if next station is not defined
        if next_station is None:
            return train, None, None, None

        for stop in all_stops:
            station = stop.get('station', {})
            eva_nr = station.get('evaNr')
            station_name = station.get('name', '')
            delay = stop.get('timetable', {}).get('arrivalDelay', 0)

            # Get coordinates
            coordinates = station.get('geocoordinates', {})
            latitude = coordinates.get('latitude')
            longitude = coordinates.get('longitude')

            # Handle coordinates
            if latitude is not None and longitude is not None:
                location = (latitude, longitude)
            else:
                location = None

            # Remove leading plus (+) character from delay information
            if isinstance(delay, str) and delay.startswith('+'):
                delay = int(delay.lstrip('+'))
            else:
                delay = 0

            # Return delay data if eva number matches with next station
            if eva_nr == next_station:
                return train, station_name, delay, location

        return train, None, None, None

    def calculate_distance(self, coordinates_from, coordinates_to):
        """
        Calculate distance in kilometers between two coordinates.
        """

        return geodesic(coordinates_from, coordinates_to).km

def main():
    """
    Run metrics exporter.
    """

    try:
        handler = logging.StreamHandler(sys.stdout)
        logger = logging.getLogger()
        logger.addHandler(handler)
        logger.setLevel(logging.DEBUG)

        REGISTRY.register(DbTrainMetricsCollector(logger))

        logger.debug('Starting server at http://localhost:8080...')
        start_http_server(8080)

        # Collect metrics every 10 seconds
        while True:
            time.sleep(10)
    except KeyboardInterrupt:
        logger.debug('Received keyboard interrupt, exiting.')
        sys.exit(0)

if __name__ == '__main__':
    main()
