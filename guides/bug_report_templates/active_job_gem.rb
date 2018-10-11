# frozen_string_literal: true

begin
  require "bundler/inline"
rescue LoadError => e
  $stderr.puts "Bundler version 1.10 or later is required. Please update your Bundler"
  raise e
end

gemfile(true) do
  source "https://rubygems.org"

  git_source(:github) { |repo| "https://github.com/#{repo}.git" }

  # Activate the gem you are reporting the issue against.
  gem "activejob", "5.2.0"
end

require "minitest/autorun"
require "active_job"

# Ensure backward compatibility with minitest 4.
Minitest::Test = MiniTest::Unit::TestCase unless defined?(Minitest::Test)

class BuggyJob < ActiveJob::Base
  def perform
    puts "performed"
  end
end

class BuggyJobTest < ActiveJob::TestCase
  def test_stuff
    assert_enqueued_with(job: BuggyJob) do
      BuggyJob.perform_later
    end
  end
end
