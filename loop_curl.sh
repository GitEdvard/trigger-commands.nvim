#!/usr/bin/env bash

max_attemts=5
attempts_counter=0
curl localhost:2000/api/winners
until [ $? -eq 0 ]; do
    if [ ${attempts_counter} -eq ${max_attemts} ]; then
        exit
    fi
    attempts_counter=$((attempts_counter+1))
    printf '.'
    sleep 1
    curl localhost:2000/api/winners
done
