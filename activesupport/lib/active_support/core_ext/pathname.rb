require 'pathname'
require 'active_support/core_ext/pathname/clean_within'

class Pathname#:nodoc:
  extend ActiveSupport::CoreExtensions::Pathname::CleanWithin
end

