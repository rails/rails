# frozen_string_literal: true

if defined?(RubyVM::YJIT)
  if RubyVM::YJIT.enabled?
    puts "YJIT enabled? #{RubyVM::YJIT.enabled?}"
  else
    puts "YJIT is defined but not enabled"
  end
else
  puts "YJIT is not enabled or defined."
end

if ENV["BUILDKITE"]
  require "minitest-ci"

  Minitest::Ci.report_dir = File.join(__dir__, "../test-reports/#{ENV['BUILDKITE_JOB_ID']}")
end
