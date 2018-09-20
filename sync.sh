#!/bin/bash

if [ -z "$SRC_URI" ]; then
    echo "URI enviroment variable is not present!"
    exit 1
fi 

if [ -z "$DEST" ]; then
    echo "DEST enviroment variable is not present!"
    exit 1
fi 

date
echo "Setting facts ..."
# extract the protocol
if [ -z $(echo URI | grep ://)]
then
    proto="${SRC_URI%%://*}"
fi

url=$(echo $SRC_URI | sed -e s,$proto://,,g)

# extract the user (if any)
user="$(echo $url | grep @ | cut -d@ -f1)"
if [[ $user =~ ":" ]]
then
  password="$(echo $user | grep : | cut -d: -f2)"
  user="$(echo $user | grep : | cut -d: -f1)"
  host=$(echo $url | sed -e s,$user:$password@,,g | cut -d/ -f1)
else
  host=$(echo $url | sed -e s,$user@,,g | cut -d/ -f1)
fi

if [[ $host =~ ":" ]]
then
   # get port first and then cut it from host
   port="$(echo $host | sed -e 's,^.*:,:,g' -e 's,.*:\([0-9]*\).*,\1,g' -e 's,[^0-9],,g')"
   host="$(echo $host | grep : | cut -d: -f1)"
fi

#add the / because cut removes it from the URI and we are working with absolute directory paths
path="/$(echo $url | grep / | cut -d/ -f2-)"

namespace="$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace)"
token="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)"
hostname="$(hostname)"

echo "url: $url"
echo "proto: $proto"
echo "user: $user"
echo "password: $password"
echo "host: $host"
echo "port: $port"
echo "path: $path"
echo "dest: $DEST"
echo "namespace: $namespace"
echo "pod name: $hostname"
echo ""

echo "Starting a ssh test to see if the target server is reachable."

if [ -n "$password" ]
then
  sshpass -p $password ssh -q -o StrictHostKeyChecking=no $user@$host exit
else 
  ssh -q -i $KEY -o StrictHostKeyChecking=no $user@$host exit
fi
#check return code and exit if target server was not reachable
rc=$? 
if [[ $rc != 0 ]] 
then
  echo "ssh connection test failed. Exiting..."
  exit $rc
fi
echo ""

echo "Starting rsync of $path"
if [ -n "$password" ]
then
  sshpass -p $password rsync --rsync-path='sudo rsync' --progress -avz -e 'ssh -q -o StrictHostKeyChecking=no' $user@$host:$path $DEST
else 
  rsync --rsync-path='sudo rsync' --progress -avz -e 'ssh -i $KEY -q -o StrictHostKeyChecking=no' $user@$host:$path $DEST
fi

rc=$? 
if [[ $rc != 0 ]] 
then
  echo "There was an error with the rsync. You might need to check your files."
  exit $rc
fi

echo "rsync complete with no errors!"
echo ""
podlabels="$(curl -s -H "Authorization: Bearer $token" --cacert /var/run/secrets/kubernetes.io/serviceaccount/ca.crt https://$KUBERNETES_SERVICE_HOST:$KUBERNETES_SERVICE_PORT/api/v1/namespaces/$namespace/pods |  jq -r '.items[].metadata.name')"
podlabels=($podlabels)
for podlabel in "${podlabels[@]}"
do
  if [[ "$podlabel" != "$hostname" ]]
  then
    echo "Deleting POD with name $podlabel"
    curl -X DELETE -s --output /dev/null -H "Authorization: Bearer $token" --cacert /var/run/secrets/kubernetes.io/serviceaccount/ca.crt https://$KUBERNETES_SERVICE_HOST:$KUBERNETES_SERVICE_PORT/api/v1/namespaces/$namespace/pods?fieldSelector=metadata.name=$podlabel
  fi
done
