# frozen_string_literal: true

STATS_DIRECTORIES = ActiveSupport::Deprecation::DeprecatedObjectProxy.new(
  Rails.application.config.code_statistics.directories,
  "`STATS_DIRECTORIES` is deprecated! Use `Rails.application.config.code_statistics.directories` instead.",
  Rails.deprecator
)

desc "Report code statistics (KLOCs, etc) from the application or engine"
task :stats do
  require "rails/code_statistics"
  stat_directories = Rails.application.config.code_statistics.directories.collect do |name, dir|
    [ name, "#{File.dirname(Rake.application.rakefile_location)}/#{dir}" ]
  end.select { |name, dir| File.directory?(dir) }
  CodeStatistics.new(*stat_directories).to_s
end
