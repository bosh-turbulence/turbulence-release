#!/bin/bash

set -e -x
set -u

echo "-----> $(date): Upload stemcell"
bosh upload-stemcell --sha1 99a0cd90a4cdfcc50ece4589f130355d0232504c \
  https://bosh.io/d/stemcells/bosh-warden-boshlite-ubuntu-xenial-go_agent?v=97.22

echo "-----> `date`: Delete previous deployment"
bosh -n -d turbulence delete-deployment --force
rm -f creds.yml

echo "-----> $(date): Deploy"
( set -e; cd ./..; 
  bosh -n -d turbulence deploy ./manifests/example.yml -o ./manifests/dev.yml \
  -v turbulence_api_ip=10.244.0.34 \
  -v director_ip=192.168.50.6 \
  -v director_client=admin \
  -v director_client_secret=$(bosh int ~/workspace/deployments/vbox/creds.yml --path /admin_password) \
  --var-file director_ssl.ca=<(bosh int ~/workspace/deployments/vbox/creds.yml --path /director_ssl/ca) \
  --vars-store ./tests/creds.yml )

echo "-----> $(date): Deploy dummy"
( set -e; cd ./..; bosh -n -d dummy deploy ./manifests/dummy.yml )

echo "-----> $(date): Kill dummy"
export TURBULENCE_HOST=10.244.0.34
export TURBULENCE_PORT=8080
export TURBULENCE_USERNAME=turbulence
pushd ${bin}/../src/turbulence/
  ginkgo -r turbulence-example-test/
popd

echo "-----> $(date): Delete deployments"
bosh -n -d dummy delete-deployment
bosh -n -d turbulence delete-deployment

echo "-----> $(date): Done"
