web: bundle exec rails server --port $PORT
worker: bundle exec rake jobs:update_events_loop
background: bundle exec rake jobs:work
