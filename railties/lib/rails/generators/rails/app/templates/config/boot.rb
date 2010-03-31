<% if options[:skip_bundler] -%>
require 'rubygems'
<% else -%>
# Use Bundler (preferred)
begin
  require File.expand_path('../../.bundle/environment', __FILE__)
rescue LoadError
  require 'rubygems'
  require 'bundler'
  Bundler.setup
end
<% end -%>
