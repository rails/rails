# Be sure to restart your server when you modify this file.
#
# This file contains the settings for ActionController::ParametersWrapper
# which will be enabled by default in the upcoming version of Ruby on Rails.

# Enable parameter wrapping for JSON. You can disable this by set :format to empty array.
ActionController::Base.wrap_parameters :format => [:json]

# Disable root element in JSON by default.
if defined?(ActiveRecord)
  ActiveRecord::Base.include_root_in_json = false
end
