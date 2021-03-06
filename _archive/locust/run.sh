#!/bin/bash

###
# Usage:
#
# Export values for the following env variables.
#
# Required:
# BB_CLIENT_ID (application's client id)
# BB_CLIENT_SECRET (application's client secret)
# BB_SUB_DOMAIN (sub domain to test against, e.g., sandbox.bluebutton.cms.gov)
# BB_LOAD_TEST_TYPE (either "eob" or "all" -- the endpoints to include in the test)
#
# Optional:
# BB_NUM_BENES (number of synthetic benes, default: 4)
# BB_LOAD_TEST_DURATION (number of seconds, default: 20)
# BB_LOAD_TEST_HATCH_RATE (hatch rate for clients added per second, default: 1)
# BB_LOAD_TEST_MIN_WAIT (how many ms to wait between requests, lower bound, default: 1000)
# BB_LOAD_TEST_MAX_WAIT (how many ms to wait between requests, upper bound, default: 5000)
# BB_TKNS_WORKERS (how many tkns workers to use when fetching access tokens, default: 2)
###

set -e

BB_LOAD_TEST_TYPE="${1:-BB_LOAD_TEST_TYPE}"

if [ "$BB_LOAD_TEST_TYPE" != "eob" ] && [ "$BB_LOAD_TEST_TYPE" != "all" ]
then
  echo "Must specify a load test type (eob|all)" >&2
  exit 1
fi

docker build -f ./Dockerfiles/Dockerfile.tkns -t bb_tkns .
docker build -f ./Dockerfiles/Dockerfile.locust -t bb_locust .

echo "Get access tokens..."
docker run --rm -t bb_tkns \
  -w ${BB_TKNS_WORKERS:-2} \
  -id $BB_CLIENT_ID \
  -secret $BB_CLIENT_SECRET \
  -url https://${BB_SUB_DOMAIN} \
  -prep-url ${BB_PREP_URL} \
  -n ${BB_NUM_BENES:-4} > tkns.txt

echo "Using access tokens..."
echo "---"
cat tkns.txt
echo "---"

echo "Run locust tests..."
docker run \
  -v "$(pwd):/code" \
  -e BB_TKNS_FILE=/code/tkns.txt \
  -e BB_LOAD_TEST_BASE_URL=https://${BB_SUB_DOMAIN} \
  -e BB_LOAD_TEST_MIN_WAIT=${BB_LOAD_TEST_MIN_WAIT:-1000} \
  -e BB_LOAD_TEST_MAX_WAIT=${BB_LOAD_TEST_MAX_WAIT:-5000} \
  -e BB_CLIENT_ID=${BB_CLIENT_ID} \
  -e BB_CLIENT_SECRET=${BB_CLIENT_SECRET} \
  --rm -t bb_locust \
  --host https://${BB_SUB_DOMAIN} \
  --no-web \
  --only-summary \
  -f locustfiles/${BB_LOAD_TEST_TYPE}.py \
  -c ${BB_NUM_BENES:-4} \
  -r ${BB_LOAD_TEST_HATCH_RATE:-1} \
  -t ${BB_LOAD_TEST_DURATION:-20}

rm tkns.txt
