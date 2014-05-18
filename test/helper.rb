require 'bundler'
Bundler.setup

$LOAD_PATH << File.dirname(__FILE__ + "/../lib")

require 'active_job'

require 'active_support/testing/autorun'
