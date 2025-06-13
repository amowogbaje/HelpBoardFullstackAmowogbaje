#!/bin/bash

# Fix Docker Compose command format in all deployment scripts
echo "Fixing Docker Compose command format..."

# Update update-deployment.sh
sed -i 's/docker-compose/docker compose/g' update-deployment.sh

# Update deploy-dev.sh
sed -i 's/docker-compose/docker compose/g' deploy-dev.sh

# Update deploy.sh
sed -i 's/docker-compose/docker compose/g' deploy.sh

echo "Docker Compose commands updated to new format"

# Also fix any remaining references in other files
find . -name "*.sh" -type f -exec sed -i 's/docker-compose/docker compose/g' {} \;

echo "All Docker Compose references updated"