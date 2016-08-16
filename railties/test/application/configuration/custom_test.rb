require 'application/configuration/base_test'

class ApplicationTests::ConfigurationTests::CustomTest < ApplicationTests::ConfigurationTests::BaseTest
  test 'access custom configuration point' do
    add_to_config <<-RUBY
      config.x.payment_processing.schedule = :daily
      config.x.payment_processing.retries  = 3
      config.x.super_debugger              = true
      config.x.hyper_debugger              = false
      config.x.nil_debugger                = nil
    RUBY
    require_environment

    x = Rails.configuration.x
    assert_equal :daily, x.payment_processing.schedule
    assert_equal 3, x.payment_processing.retries
    assert_equal true, x.super_debugger
    assert_equal false, x.hyper_debugger
    assert_equal nil, x.nil_debugger
    assert_nil x.i_do_not_exist.zomg
    assert_equal true, x.respond_to?(:i_do_not_exist)
    assert_kind_of Method, x.method(:i_do_not_exist)
    assert_kind_of ActiveSupport::OrderedOptions, x.i_do_not_exist
  end
end
