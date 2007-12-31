require 'rubygems'
require 'spec'
require File.join(File.dirname(__FILE__), '..', 'lib', 'sql_algebra')
require File.join(File.dirname(__FILE__), 'spec_helpers', 'be_like')

Spec::Runner.configure do |config|  
  config.include(BeLikeMatcher)
end