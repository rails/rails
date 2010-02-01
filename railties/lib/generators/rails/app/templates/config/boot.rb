# Use Bundler (preferred)
begin
  require File.expand_path('../../vendor/environment', __FILE__)
rescue LoadError
  require 'rubygems'
  require 'bundler'
  Bundler.setup

  # To use 2.x style vendor/rails and RubyGems
  #
  # vendor_rails = File.expand_path('../../vendor/rails', __FILE__)
  # if File.exist?(vendor_rails)
  #   Dir["#{vendor_rails}/*/lib"].each { |path| $:.unshift(path) }
  # end
  #
  # require 'rubygems'
end

<% unless options[:skip_activerecord] -%>
require 'rails/all'

# To pick the frameworks you want, remove 'require "rails/all"'
# and list the framework railties that you want:
#
# require "active_support/railtie"
# require "active_model/railtie"
# require "active_record/railtie"
# require "action_controller/railtie"
# require "action_view/railtie"
# require "action_mailer/railtie"
# require "active_resource/railtie"
# require "rails/test_unit/railtie"
<% else -%>
# Pick the frameworks you want:
# require "active_model/railtie"
# require "active_record/railtie"
require "active_support/railtie"
require "action_controller/railtie"
require "action_view/railtie"
require "action_mailer/railtie"
require "active_resource/railtie"
require "rails/test_unit/railtie"
<% end -%>