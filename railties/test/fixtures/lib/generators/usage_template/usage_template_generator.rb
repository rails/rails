require "rails/generators"

class UsageTemplateGenerator < Rails::Generators::Base
  source_root File.expand_path("templates", File.dirname(__FILE__))
end
