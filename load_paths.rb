# bust gem prelude
if defined? Gem
  gem 'bundler'
else
  require 'rubygems'
end
require 'bundler'
Bundler.setup
