require 'application/configuration/base_test'

class ApplicationTests::ConfigurationTests::CustomTest < ApplicationTests::ConfigurationTests::BaseTest
  test 'configuration top level can be chained' do
    add_to_config <<-RUBY
      config.resque.inline_jobs = :always
      config.resque.timeout     = 60
    RUBY
    require_environment

    assert_equal :always, Rails.configuration.resque.inline_jobs
    assert_equal 60, Rails.configuration.resque.timeout
    assert_nil Rails.configuration.resque.nothing
  end

  test 'configuration top level accept normal values' do
    add_to_config <<-RUBY
      config.timeout = 60
      config.something_nil = nil
      config.something_false = false
      config.something_true = true
    RUBY
    require_environment

    assert_equal 60, Rails.configuration.timeout
    assert_equal nil, Rails.configuration.something_nil
    assert_equal false, Rails.configuration.something_false
    assert_equal true, Rails.configuration.something_true
  end

  test 'configuration top level builds options from hashes' do
    add_to_config <<-RUBY
      config.resque = { timeout: 60, inline_jobs: :always }
    RUBY
    require_environment

    assert_equal :always, Rails.configuration.resque.inline_jobs
    assert_equal 60, Rails.configuration.resque.timeout
    assert_nil Rails.configuration.resque.nothing
  end

  test 'configuration top level builds options from hashes with string keys' do
    add_to_config <<-RUBY
      config.resque = { 'timeout' => 60, 'inline_jobs' => :always }
    RUBY
    require_environment

    assert_equal :always, Rails.configuration.resque.inline_jobs
    assert_equal 60, Rails.configuration.resque.timeout
    assert_nil Rails.configuration.resque.nothing
  end

  test 'configuration top level builds nested options from hashes with symbol keys' do
    add_to_config <<-RUBY
      config.resque = { timeout: 60, inline_jobs: :always, url: { host: 'localhost', port: 8080 } }
      config.resque.url.protocol = 'https'
      config.resque.queues = { production: ['low_priority'] }
    RUBY
    require_environment

    assert_equal(:always, Rails.configuration.resque.inline_jobs)
    assert_equal(60, Rails.configuration.resque.timeout)
    assert_equal({ host: 'localhost', port: 8080, protocol: 'https' }, Rails.configuration.resque.url)
    assert_equal('localhost', Rails.configuration.resque.url.host)
    assert_equal(8080, Rails.configuration.resque.url.port)
    assert_equal('https', Rails.configuration.resque.url.protocol)
    assert_equal(['low_priority'], Rails.configuration.resque.queues.production)
    assert_nil(Rails.configuration.resque.nothing)
  end

  test 'configuration top level builds nested options from hashes with string keys' do
    add_to_config <<-RUBY
      config.resque = { 'timeout' => 60, 'inline_jobs' => :always, 'url' => { 'host' => 'localhost', 'port' => 8080 } }
    RUBY
    require_environment

    assert_equal(:always, Rails.configuration.resque.inline_jobs)
    assert_equal(60, Rails.configuration.resque.timeout)
    assert_equal({ host: 'localhost', port: 8080 }, Rails.configuration.resque.url)
    assert_equal('localhost', Rails.configuration.resque.url.host)
    assert_equal(8080, Rails.configuration.resque.url.port)
    assert_nil(Rails.configuration.resque.nothing)
  end
end
