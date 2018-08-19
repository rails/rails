# frozen_string_literal: true

require "rails/command"
require "active_support/deprecation"

desc "Print out all defined initializers in the order they are invoked by Rails."
task :initializers do
  ActiveSupport::Deprecation.warn("Using `bin/rake initializers` is deprecated and will be removed in Rails 6.1. Use `bin/rails initializers` instead.\n")
  Rails::Command.invoke "initializers"
end
