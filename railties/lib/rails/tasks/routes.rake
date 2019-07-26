# frozen_string_literal: true

require "rails/command"
require "active_support/deprecation"

task routes: :environment do
  ActiveSupport::Deprecation.warn("Using `bin/rake routes` is deprecated and will be removed in Rails 6.1. Use `bin/rails routes` instead.\n")
  Rails::Command.invoke "routes"
end
