#!/bin/bash


if [[ ! -d metasploit-framework ]]; then
  git clone https://github.com/rapid7/metasploit-framework.git
  cd metasploit-framework && mv Dockerfile Dockerfile.original && mv .dockerignore .dockerignore.original
else
  cd metasploit-framework && git pull
fi

cp -f ../Dockerfile .
cp -f ../.dockerignore .
