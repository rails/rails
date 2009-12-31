# Use Bundler (preferred)
environment = File.expand_path('../../vendor/gems/environment', __FILE__)
if File.exist?("#{environment}.rb")
  require environment

# Use 2.x style vendor/rails and RubyGems
else
  vendor_rails = File.expand_path('../../vendor/rails', __FILE__)
  if File.exist?(vendor_rails)
    Dir["#{vendor_rails}/*/lib"].each { |path| $:.unshift(path) }
  end

  require 'rubygems'
end

require 'rails'
# To skip frameworks you're not going to use, change require "rails"
# to require "rails/core" and list the frameworks that you are going
# to use.
#
# require "rails/core"
# require "active_model/rails"
# require "active_record/rails"
# require "action_controller/rails"
# require "action_view/rails"
# require "action_mailer/rails"
# require "active_resource/rails"