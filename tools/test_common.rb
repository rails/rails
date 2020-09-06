# frozen_string_literal: true

if ENV['BUILDKITE']
  require 'minitest/reporters'
  require 'fileutils'

  module Minitest
    def self.plugin_rails_ci_junit_format_test_report_for_buildkite_init(*)
      dir = File.join(__dir__, "../test-reports/#{ENV['BUILDKITE_JOB_ID']}")
      reporter << Minitest::Reporters::JUnitReporter.new(dir, false)
      FileUtils.mkdir_p(dir)
    end
  end

  Minitest.load_plugins
  Minitest.extensions.unshift 'rails_ci_junit_format_test_report_for_buildkite'
end
