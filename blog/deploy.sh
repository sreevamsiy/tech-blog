#!/usr/bin/env bash
set -euo pipefail

BUCKET_NAME="${BUCKET_NAME:?Set BUCKET_NAME before running deploy.sh}"
CLOUDFRONT_DISTRIBUTION_ID="${CLOUDFRONT_DISTRIBUTION_ID:?Set CLOUDFRONT_DISTRIBUTION_ID before running deploy.sh}"

cd "$(dirname "$0")"

rm -rf public
hugo --environment production

aws s3 sync public/ "s3://${BUCKET_NAME}/" --delete

aws cloudfront create-invalidation \
  --distribution-id "${CLOUDFRONT_DISTRIBUTION_ID}" \
  --paths "/*"
