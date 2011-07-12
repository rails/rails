require File.expand_path('../boot', __FILE__)

<% if include_all_railties? -%>
require 'rails/all'
<% else -%>
# Pick the frameworks you want:
<%= comment_if :skip_active_record %>require "active_record/railtie"
require "action_controller/railtie"
require "action_mailer/railtie"
require "active_resource/railtie"
<%= comment_if :skip_sprockets %>require "sprockets/railtie"
<%= comment_if :skip_test_unit %>require "rails/test_unit/railtie"
<% end -%>

Bundler.require
require "<%= name %>"

<%= application_definition %>
