#!/bin/bash

IMG='starina/nwaf-dyn-ce-nginx-ui'
TAG='latest'

VF="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )/VERSION"
YMD="$(date '+%y.%-m.%-d')"

[[ -f "$VF" ]] && {
    V="$(head -n 1 "$VF")"
    [[ $V =~ ^$YMD\.[0-9]+$ ]] && V="$(echo $V | awk -F. -v OFS=. '{$NF++; print}')" || V="$YMD.1"
} || V="$YMD.1"

[[ $V =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] && {
    docker image build --network host --add-host=github.com:140.82.121.3 --add-host=api.github.com:140.82.121.5 -t $IMG:$V -t $IMG:$TAG . && [[ -z $1 ]] && echo "$V">"$VF" && docker push $IMG:$V && docker push $IMG:$TAG
}
