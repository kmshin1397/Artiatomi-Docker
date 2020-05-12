#!/bin/bash
# This script stops and removes any running Artiatomi Docker containers.

if $(sudo docker container ls | grep -q artia-clicker); then 
	echo "Closing Artiatomi Clicker container"
    sudo docker stop artia-clicker && sudo docker rm artia-clicker
    exit; 
else
	echo "Closing Artiatomi container"
	sudo docker stop artia && sudo docker rm artia
	exit;
fi