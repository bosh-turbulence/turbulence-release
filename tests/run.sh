#!/bin/bash

set -e 
set -u
[[ -z "${DEBUG:-}" ]] || set -x

bin=$(cd "$(dirname "$0")"; pwd)
creds=$(mktemp)
export GO111MODULE=on
echo "-----> `date`: Upload stemcell"
bosh upload-stemcell --sha1 99a0cd90a4cdfcc50ece4589f130355d0232504c \
  https://bosh.io/d/stemcells/bosh-warden-boshlite-ubuntu-xenial-go_agent?v=97.22

echo "-----> $(date): Delete previous deployment"
bosh -n -d turbulence delete-deployment --force
trap 'rm -f "$creds"' EXIT SIGINT SIGQUIT

echo "-----> $(date): Deploy"
pushd "${bin}/.."
  bosh -n -d turbulence deploy ./manifests/example.yml -o ./manifests/dev.yml \
  -v turbulence_api_ip=10.244.0.34 \
  -v director_ip=192.168.50.6 \
  -v director_client=admin \
  -v "director_client_secret=$(bosh int ~/workspace/deployments/bosh-lite/creds.yml --path /admin_password)" \
  --var-file director_ssl.ca=<(bosh int ~/workspace/deployments/bosh-lite/creds.yml --path /director_ssl/ca) \
  --vars-store "$creds"

  echo "-----> $(date): Deploy dummy"
bosh -n -d dummy deploy ./manifests/dummy.yml
popd

echo "-----> $(date): Kill dummy"
TURBULENCE_HOST=10.244.0.34
TURBULENCE_PORT=8080
TURBULENCE_USERNAME=turbulence
TURBULENCE_PASSWORD=$(bosh int "$creds" --path /turbulence_api_password)
TURBULENCE_CA_CERT=$(bosh int "$creds" --path /turbulence_api_cert/ca)
export TURBULENCE_HOST TURBULENCE_PORT TURBULENCE_USERNAME TURBULENCE_PASSWORD TURBULENCE_CA_CERT
pushd ${bin}/../src/turbulence/
  ginkgo -r turbulence-example-test/
popd

echo "-----> $(date): Delete deployments"
bosh -n -d dummy delete-deployment
bosh -n -d turbulence delete-deployment

echo "-----> $(date): Done"
