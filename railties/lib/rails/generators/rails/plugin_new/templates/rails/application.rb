require File.expand_path('../boot', __FILE__)

<% unless options[:skip_active_record] -%>
require 'rails/all'
<% else -%>
# require "active_record/railtie"
require "action_controller/railtie"
require "action_mailer/railtie"
require "active_resource/railtie"
require "rails/test_unit/railtie"
<% end -%>

Bundler.require
require "<%= name %>"

<%= application_definition %>
