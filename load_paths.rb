# bust gem prelude
if defined? Gem
  Gem.source_index
  gem 'bundler'
else
  require 'rubygems'
end
require 'bundler'
Bundler.setup