# frozen_string_literal: true

unless defined?(ActiveStorage)
  PATH_TO_ACTIVESTORAGE = File.expand_path("../../activestorage", __dir__)
  raise LoadError, "#{PATH_TO_ACTIVESTORAGE} doesn't exist" unless File.directory?(PATH_TO_ACTIVESTORAGE)
  $LOAD_PATH.unshift "#{PATH_TO_ACTIVESTORAGE}/test"

  require "test_helper"
  require "database/setup"
end
