#!/bin/bash

_PWD=$1
_HOSTNAME=$(hostname)
mkdir $_PWD/$_HOSTNAME
cd $_PWD/$_HOSTNAME
pwd
crictl ps -a > crictl_ps_a_${_HOSTNAME}


#a9af3358a2c50       0a03d1158b280       About an hour ago   Running             utils                         0                   5d69810783cf5       0-sr-b371603c-c97b-472b-aa38-6674e73c574e

for _LINE in $(crictl ps -a |grep -E -e "hour" -e "2 days ago" |awk '{print $1","$(NF-4)","$(NF-3)","$(NF)}')
do
	_POD=$(echo $_LINE|cut -d, -f4)
	_NAME=$(echo $_LINE|cut -d, -f3)
	_STAT=$(echo $_LINE|cut -d, -f2)
	_FID=$(echo $_LINE|cut -d, -f1)

        crictl logs --timestamps $_FID > stat.${_STAT}.pod.${_POD}.cont.${_NAME}.fid.${_FID} 2>&1

done

