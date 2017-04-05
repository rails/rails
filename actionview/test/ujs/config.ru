$LOAD_PATH.unshift File.expand_path("..", __FILE__)
require "server"

run UJS::Server
