# frozen_string_literal: true

require "rails/command"
require "active_support/deprecation"

task :initializers do
  ActiveSupport::Deprecation.warn("Using `bin/rake initializers` is deprecated and will be removed in Rails 6.1. Use `bin/rails initializers` instead.\n")
  Rails::Command.invoke "initializers"
end
