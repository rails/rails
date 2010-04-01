# Use locked gems if present.
begin
  require File.expand_path('../../.bundle/environment', __FILE__)

rescue LoadError
  # Otherwise, use RubyGems.
  require 'rubygems'

  # And set up the gems listed in the Gemfile.
  if File.exist?(File.expand_path('../../Gemfile', __FILE__))
    require 'bundler'
    Bundler.setup
  end
end
