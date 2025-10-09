# frozen_string_literal: true

Rails.deprecator.warn <<~TEXT
  rails/tasks/statistics.rake is deprecated and will be removed in Rails 8.2 without replacement.
TEXT

require "rails/code_statistics"
STATS_DIRECTORIES = ActiveSupport::Deprecation::DeprecatedObjectProxy.new(
  Rails::CodeStatistics::DIRECTORIES,
  "`STATS_DIRECTORIES` is deprecated and will be removed in Rails 8.1! Use `Rails::CodeStatistics.register_directory('My Directory', 'path/to/dir)` instead.",
  Rails.deprecator
)
