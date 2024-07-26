#!/usr/local/bin/ruby

require File.dirname(__FILE__) + "/../config/environments/production"

# If you're using RubyGems and mod_ruby, this require should be changed to an absolute path one, like:
# "/usr/local/lib/ruby/gems/1.8/gems/rails-0.8.0/lib/dispatcher" -- otherwise performance is severely impaired
require "dispatcher"

ADDITIONAL_LOAD_PATHS.each { |dir| $:.unshift "#{File.dirname(__FILE__)}/../#{dir}" }
Dispatcher.dispatch