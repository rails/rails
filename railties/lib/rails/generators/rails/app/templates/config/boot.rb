# Package management
# Choose one

# Use Bundler (preferred)
environment = File.expand_path('../../vendor/gems/environment', __FILE__)
require environment if File.exist?(environment)

# Use 2.x style vendor/rails directory
vendor_rails = File.expand_path('../../vendor/rails', __FILE__)
Dir["#{vendor_rails}/*/lib"].each { |path| $:.unshift(path) } if File.exist?(vendor_rails)

# Load Rails from traditional RubyGems
require 'rubygems'

require 'rails'
