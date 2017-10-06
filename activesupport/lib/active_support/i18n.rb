# frozen_string_literal: true

require_relative "core_ext/hash/deep_merge"
require_relative "core_ext/hash/except"
require_relative "core_ext/hash/slice"
begin
  require "i18n"
rescue LoadError => e
  $stderr.puts "The i18n gem is not available. Please add it to your Gemfile and run bundle install"
  raise e
end
require_relative "lazy_load_hooks"

ActiveSupport.run_load_hooks(:i18n)
I18n.load_path << File.expand_path("locale/en.yml", __dir__)
