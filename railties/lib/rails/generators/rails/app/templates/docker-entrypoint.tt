#!/bin/sh

if [ $# -eq 0 ]; then
  # Create new or migrate existing database
  ./bin/rails db:prepare

  # Start the server by default
  exec bin/rails server
else
  # Allow other commands, like console or runner, to be called
  exec bin/rails "$@"
fi
