require 'active_support/core_ext/hash/deep_merge'
require 'active_support/core_ext/hash/except'
require 'active_support/core_ext/hash/slice'

begin
  require 'i18n'
  require 'active_support/lazy_load_hooks'
rescue LoadError => e
  $stderr.puts "The i18n gem is not available. Please add it to your Gemfile and run bundle install"
  raise e
end

I18n.load_path << "#{File.dirname(__FILE__)}/locale/en.yml"
