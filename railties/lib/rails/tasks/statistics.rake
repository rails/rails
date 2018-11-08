# frozen_string_literal: true

require "active_support/deprecation"

class StatsDirectories
  attr_reader :value

  def initialize
    @value = []
  end

  def <<(dir)
    ActiveSupport::Deprecation.warn("`STATS_DIRECTORIES` constants is deprecated and will be removed in Rails 6.1. Use `Rails.application.config.code_statistics.directories` instead.\n")
    @value << dir
  end
end

STATS_DIRECTORIES = StatsDirectories.new

desc "Report code statistics (KLOCs, etc) from the application or engine"
task stats: :environment do
  require "rails/code_statistics"
  directories = Rails.application.config.code_statistics.directories + STATS_DIRECTORIES.value
  puts CodeStatistics.new(*directories).to_s
end
