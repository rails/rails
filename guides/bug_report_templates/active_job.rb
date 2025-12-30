# frozen_string_literal: true

require "bundler/inline"

gemfile(true) do
  source "https://rubygems.org"

  gem "rails"
  # If you want to test against edge Rails replace the previous line with this:
  # gem "rails", github: "rails/rails", branch: "main"
end

require "active_job/railtie"
require "minitest/autorun"

class TestApp < Rails::Application
  config.load_defaults Rails::VERSION::STRING.to_f
  config.eager_load = false
  config.secret_key_base = "secret_key_base"
  config.active_job.queue_adapter = :test

  config.logger = Logger.new($stdout)
end
Rails.application.initialize!

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
