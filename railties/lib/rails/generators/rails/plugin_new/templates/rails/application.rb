require File.expand_path('../boot', __FILE__)

<% if include_all_railties? -%>
require 'rails/all'
<% else -%>
# Pick the frameworks you want:
<%= comment_if :skip_active_record %>require "active_record/railtie"
require "action_controller/railtie"
require "action_mailer/railtie"
<%= comment_if :skip_sprockets %>require "sprockets/rails/railtie"
<%= comment_if :skip_test_unit %>require "rails/test_unit/railtie"
<% end -%>

if defined?(Bundler)
  # If you precompile assets before deploying to production, use this line
  Bundler.require(*Rails.groups(:assets => %w(development test)))
  # If you want your assets lazily compiled in production, use this line
  # Bundler.require(:default, :assets, Rails.env)
end

require "<%= name %>"

<%= application_definition %>
