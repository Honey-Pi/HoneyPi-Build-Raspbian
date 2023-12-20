#!/bin/bash
rm -R pi-gen
docker container stop pigen_work
docker rm -v --force pigen_work
