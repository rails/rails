begin
  require File.expand_path('../.bundle/environment', __FILE__)
rescue LoadError
  begin
    require 'rubygems'
    require 'bundler'
    Bundler.setup
  rescue LoadError
  end
end
