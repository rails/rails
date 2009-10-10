require 'isolation/abstract_unit'

class ConsoleTest < Test::Unit::TestCase
  include ActiveSupport::Testing::Isolation

  def setup
    build_app
    boot_rails

    # Load steps taken from rails/commands/console.rb
    require "#{rails_root}/config/environment"
    require 'rails/console_app'
    require 'rails/console_with_helpers'
  end

  def test_app_method_should_return_integration_session
    console_session = app
    assert_not_nil console_session
    assert_instance_of ActionController::Integration::Session, console_session
  end

  def test_new_session_should_return_integration_session
    session = new_session
    assert_not_nil session
    assert_instance_of ActionController::Integration::Session, session
  end

  def test_reload_should_fire_preparation_callbacks
    a = b = c = nil

    # TODO: These should be defined on the initializer
    ActionDispatch::Callbacks.to_prepare { a = b = c = 1 }
    ActionDispatch::Callbacks.to_prepare { b = c = 2 }
    ActionDispatch::Callbacks.to_prepare { c = 3 }

    # Hide Reloading... output
    silence_stream(STDOUT) do
      reload!
    end

    assert_equal 1, a
    assert_equal 2, b
    assert_equal 3, c
  end

  def test_access_to_helpers
    assert_not_nil helper
    assert_instance_of ActionView::Base, helper
    assert_equal 'Once upon a time in a world...',
      helper.truncate('Once upon a time in a world far far away')
  end
end
