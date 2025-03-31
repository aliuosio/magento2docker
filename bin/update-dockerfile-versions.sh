#!/bin/bash

# Source the .env file to get the current versions
source .env

# Define the Dockerfile path
DOCKERFILE="Dockerfile"

# Update OpenSearch version in the Dockerfile
echo "Updating OpenSearch version to $OPENSEARCH_VERSION"
sed -i "s|COPY --from=opensearchproject/opensearch:[^ ]* --chown=opensearch:opensearch|COPY --from=opensearchproject/opensearch:$OPENSEARCH_VERSION --chown=opensearch:opensearch|g" $DOCKERFILE

# Update Nginx version in the Dockerfile
echo "Updating Nginx version to $NGINX_VERSION"
sed -i "s|COPY --from=nginx:[^ ]* --chown=nginx:nginx|COPY --from=nginx:$NGINX_VERSION --chown=nginx:nginx|g" $DOCKERFILE

echo "Dockerfile updated successfully with:"
echo "- OpenSearch version: $OPENSEARCH_VERSION"
echo "- Nginx version: $NGINX_VERSION"
