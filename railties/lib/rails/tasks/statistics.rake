# frozen_string_literal: true

require "rails/code_statistics"
STATS_DIRECTORIES = ActiveSupport::Deprecation::DeprecatedObjectProxy.new(
  Rails::CodeStatistics::DIRECTORIES,
  "`STATS_DIRECTORIES` is deprecated and will be removed in Rails 8.1! Use `Rails::CodeStatistics.register_directory('My Directory', 'path/to/dir)` instead.",
  Rails.deprecator
)

desc "Report code statistics (KLOCs, etc) from the application or engine"
task :stats do
  require "rails/code_statistics"
  stat_directories = STATS_DIRECTORIES.collect do |name, dir|
    [ name, "#{File.dirname(Rake.application.rakefile_location)}/#{dir}" ]
  end.select { |name, dir| File.directory?(dir) }

  $stderr.puts Rails.deprecator.warn(<<~MSG, caller_locations(0..1))
  `bin/rake stats` has been deprecated and will be removed in Rails 8.1.
  Please use `bin/rails stats` as Rails command instead.\n
  MSG

  Rails::CodeStatistics.new(*stat_directories).to_s
end
