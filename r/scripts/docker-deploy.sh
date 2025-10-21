#!/bin/sh
# Deploy docker image

# login (when needed)
# aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin 083481224424.dkr.ecr.us-west-2.amazonaws.com

docker build -t aktemp/aktempviz-data --platform linux/amd64 .
docker tag aktemp/aktempviz-data:latest 083481224424.dkr.ecr.us-west-2.amazonaws.com/aktemp/aktempviz-data:latest
docker push 083481224424.dkr.ecr.us-west-2.amazonaws.com/aktemp/aktempviz-data:latest
