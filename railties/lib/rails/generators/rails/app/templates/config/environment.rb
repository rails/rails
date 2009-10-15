# Be sure to restart your server when you modify this file

# Specifies gem version of Rails to use when vendor/rails is not present
<%= '# ' if options[:freeze] %>RAILS_GEM_VERSION = '<%= Rails::VERSION::STRING %>' unless defined? RAILS_GEM_VERSION

# Load the rails application
require File.expand_path(File.join(File.dirname(__FILE__), 'application'))
# Initialize the rails application
Rails.application.new
