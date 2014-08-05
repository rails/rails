require 'application/configuration/base_test'

class ApplicationTests::ConfigurationTests::CustomTest < ApplicationTests::ConfigurationTests::BaseTest
  test 'access custom configuration point' do
    add_to_config <<-RUBY
      config.x.resque.inline_jobs = :always
      config.x.resque.timeout     = 60
    RUBY
    require_environment

    assert_equal :always, Rails.configuration.x.resque.inline_jobs
    assert_equal 60, Rails.configuration.x.resque.timeout
    assert_nil Rails.configuration.x.resque.nothing
  end
end
