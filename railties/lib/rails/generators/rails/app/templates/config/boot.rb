# Package management
# Choose one

environment = File.expand_path('../../vendor/gems/environment', __FILE__)
vendor_rails = File.expand_path('../../vendor/rails', __FILE__)

if File.exist?(environment)
  # Use Bundler (preferred)
  require environment
elsif File.exist?(vendor_rails)
  # Use 2.x style vendor/rails directory
  Dir["#{vendor_rails}/*/lib"].each { |path| $:.unshift(path) }
else
  # Load Rails from traditional RubyGems
  require 'rubygems'
end

require 'rails'
