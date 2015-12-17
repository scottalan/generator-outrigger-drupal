#!/usr/bin/env bash
##
# Start
#
# This script takes your freshly cloned repository and takes it to a working
# Drupal site hosted in a Docker container stack.
#
# Arguments:
#  - environment: The first argument is an environment designator. This is not
#    validated, if the name is not a supported environment this script will
#    have multiple failures. Default value: `local`.
#  - project name: Optional. This argument defines the project name, which in
#    combination with the environment designator, is used to define a unique,
#    project specific name for docker-compose.
##

DOCKER_ENV=$1
COMPOSE_EXT=".$1"
if [[ -z $DOCKER_ENV ]]; then
  DOCKER_ENV=local
fi

COMPOSE_PROJECT=$2
if [[ -z $COMPOSE_PROJECT ]]; then
  COMPOSE_PROJECT="-p <%= projectName %>_${COMPOSE_EXT}"
fi

if [[ $DOCKER_ENV == 'local' ]]; then
  COMPOSE_EXT=''
  COMPOSE_PROJECT=''
fi

# Spin up cache and db services to support build container.
# Web container might take file locks on existing code, blocking the build process.
docker-compose -f docker-compose$COMPOSE_EXT.yml ${COMPOSE_PROJECT} up -d <% if(cacheExternal) { %>cache <% } %>db

# Build, run static analysis, and install the site.
docker-compose -f build$COMPOSE_EXT.yml ${COMPOSE_PROJECT} run --rm cli sh -c "\
npm install && \
grunt --force && \
grunt install --no-db-load"

# Now safe to activate web container to support end-to-end testing.
docker-compose -f docker-compose$COMPOSE_EXT.yml ${COMPOSE_PROJECT} up -d www

# Correct any issues in the web container.
docker exec <%= projectName %>_${DOCKER_ENV}_www sh -c "\
chmod +x /var/www/bin/fix-perms.sh && \
/var/www/bin/fix-perms.sh"

# Wipe cache after permissions fix.
docker-compose -f build$COMPOSE_EXT.yml ${COMPOSE_PROJECT} run drush cc all
