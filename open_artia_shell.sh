#!/bin/bash
# This script opens a new shell into an existing Artiatomi container.

if $(sudo docker container ls | grep -q artia); then 
	sudo docker exec -it --user Artiatomi artia bash
fi