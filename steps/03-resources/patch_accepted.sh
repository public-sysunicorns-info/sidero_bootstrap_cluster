#!/bin/bash

set -e

_servers_object_list=$(kubectl get server -o=json | jq -r -c '.items[].metadata.name')

for _row in $( echo ${_servers_object_list}); do
    kubectl patch server $_row --type='json' -p '[{"op":"replace", "path":"/spec/accepted", "value": true}]'
done