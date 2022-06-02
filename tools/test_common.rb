# frozen_string_literal: true

if ENV["BUILDKITE"]
  require "minitest-ci"

  Minitest::Ci.report_dir = File.join(__dir__, "../test-reports/#{ENV['BUILDKITE_JOB_ID']}")
end
