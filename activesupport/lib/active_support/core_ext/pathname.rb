require 'pathname'
require File.dirname(__FILE__) + '/pathname/clean_within'

class Pathname#:nodoc:
  extend ActiveSupport::CoreExtensions::Pathname::CleanWithin
end

