#!/usr/bin/env python

import json
import logging
import sys
import time
from prometheus_client import start_http_server
from prometheus_client.core import GaugeMetricFamily, REGISTRY
from urllib.request import urlopen

class DbTrainMetricsCollector(object):
    STATUS_URL="https://iceportal.de/api1/rs/status"
    TRIP_URL="https://iceportal.de/api1/rs/tripInfo/trip"

    def __init__(self, logger):
        self.logger = logger

    def collect(self):
        speed_metric = GaugeMetricFamily('train_speed', 'Speed in km/h of the current train')
        trip_metric = GaugeMetricFamily('train_trip', 'Delay in minutes of the current trip', labels=['train', 'next_station'])

        # Collect speed and delay information
        speed = self.__collect_speed()
        train, next_station, delay = self.__collect_trip()

        # Handle speed metric
        if speed != None:
            speed_metric.add_metric([], speed)
            self.logger.debug('Extracted train speed from JSON response: %.2f', speed)
        else:
            speed_metric.add_metric([], 0.0)

        # Handle trip metric
        if train != None and next_station != None and delay != None:
            trip_metric.add_metric([train, next_station], delay)
            self.logger.debug('Extracted train from JSON response: %s', train)
            self.logger.debug('Extracted next station from JSON response: %s', next_station)
            self.logger.debug('Extracted delay from JSON response: %d', delay)
        else:
            trip_metric.add_metric(['Unknown', 'Unknown'], 0)

        yield speed_metric
        yield trip_metric

    def __collect_speed(self):
        try:
            status_response = json.load(urlopen(self.STATUS_URL))
        except json.decoder.JSONDecodeError as error:
            self.logger.error('Error while decoding JSON from %s: %s', self.STATUS_URL, str(error))
            return None

        return status_response.get('speed', 0.0)

    def __collect_trip(self):
        try:
            trip_response = json.load(urlopen(self.TRIP_URL))
        except json.decoder.JSONDecodeError as error:
            self.logger.error('Error while decoding JSON from %s: %s', self.TRIP_URL, str(error))
            return None, None, None

        # Fetch train, next station and all stops
        trip = trip_response.get('trip', {})
        train = str(trip.get('trainType', '') + ' ' + trip.get('vzn', '')).strip()
        next_station = trip.get('stopInfo', {}).get('actualNext')
        all_stops = trip.get('stops', [])

        self.logger.debug('Extracted next station from JSON response: %s', next_station)

        # Early return if next station is not defined
        if next_station == None:
            return train, None, None

        for stop in all_stops:
            station = stop.get('station', {})
            eva_nr = station.get('evaNr')
            station_name = station.get('name', '')
            delay = stop.get('timetable', {}).get('arrivalDelay', 0)

            # Remove leading plus (+) character from delay information
            if isinstance(delay, str) and delay.startswith('+'):
                delay = int(delay.lstrip('+'))

            # Return delay data if eva number matches with next station
            if eva_nr == next_station:
                return train, station_name, delay

        return train, None, None

def main():
    try:
        handler = logging.StreamHandler(sys.stdout)
        logger = logging.getLogger()
        logger.addHandler(handler)
        logger.setLevel(logging.DEBUG)

        REGISTRY.register(DbTrainMetricsCollector(logger))

        logger.debug('Starting server at http://localhost:8080...')
        server, t = start_http_server(8080)

        # Collect metrics every 3 seconds
        while True:
            time.sleep(3)
    except KeyboardInterrupt:
        logger.debug('Received keyboard interrupt, exiting.')
        exit(0)

if __name__ == '__main__':
    main()
