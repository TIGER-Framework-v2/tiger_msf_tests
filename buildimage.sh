#!/bin/bash


IMAGE_TAG="tiger-msfremote:1.0"

usage() {
  local testrc_cnt_path=/tmp/msf/test.rc
  local testrc_host_path=/tmp/test.rc

  cp -f test.rc $testrc_host_path
  echo "Examples: "
  echo "docker run --rm -v $test_rc_path:$testrc_host_path --name msftest $IMAGE_TAG /usr/src/metasploit-framework/msfconsole -r $testrc_host_path"
  echo "docker run --rm -e DATABASE_URL=\"postgres://<db-user>:<db-password>@<db-addr>:5432/<db-name>\" -v $test_rc_path:/tmp/test.rc --name msftest $IMAGE_TAG /usr/src/metasploit-framework/msfconsole -r /tmp/test.rc"
  echo "docker run --rm -e RHOST=1.1.1.1 -v $test_rc_path:/tmp/test.rc --name msftest $IMAGE_TAG /usr/src/metasploit-framework/msfconsole -r /tmp/test.rc"
}


cd metasploit-framework && docker build . -t $IMAGE_TAG && (echo "Build OK." && usage) || echo "Build FAIL."
