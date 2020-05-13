#!/bin/bash

echo 'Starting API background...'

# Wait for API
echo 'Waiting for the API...'
until curl --silent -XGET --fail http://api:${SERVER_PORT}; do echo 'Still waiting for the API...'; sleep 30; done
echo 'API started!'

# Static Files Server
echo 'Starting static files server...'
bundle exec ruby bin/static-files-server &
echo 'Static files server started!'

echo 'Starting Sidekiq...'
if [[ ${RAILS_ENV} == "development" ]]
then
  bin/sidekiq
else
  bundle exec sidekiq
fi
echo 'Sidekiq started!'
