require 'isolation/abstract_unit'

class ConsoleTest < Test::Unit::TestCase
  include ActiveSupport::Testing::Isolation

  def setup
    build_app
    boot_rails
  end

  def teardown
    teardown_app
  end

  def load_environment(sandbox = false)
    require "#{rails_root}/config/environment"
    Rails.application.load_console
  end

  def test_app_method_should_return_integration_session
    load_environment
    console_session = app
    assert_not_nil console_session
    assert_instance_of ActionController::Integration::Session, console_session
  end

  def test_new_session_should_return_integration_session
    load_environment
    session = new_session
    assert_not_nil session
    assert_instance_of ActionController::Integration::Session, session
  end

  def test_reload_should_fire_preparation_callbacks
    load_environment
    a = b = c = nil

    # TODO: These should be defined on the initializer
    ActionDispatch::Callbacks.to_prepare { a = b = c = 1 }
    ActionDispatch::Callbacks.to_prepare { b = c = 2 }
    ActionDispatch::Callbacks.to_prepare { c = 3 }

    # Hide Reloading... output
    silence_stream(STDOUT) { reload! }

    assert_equal 1, a
    assert_equal 2, b
    assert_equal 3, c
  end

  def test_reload_should_reload_constants
    app_file "app/models/user.rb", <<-MODEL
      class User
        attr_accessor :name
      end
    MODEL

    load_environment
    assert User.new.respond_to?(:name)
    assert !User.new.respond_to?(:age)

    app_file "app/models/user.rb", <<-MODEL
      class User
        attr_accessor :name, :age
      end
    MODEL

    assert !User.new.respond_to?(:age)
    silence_stream(STDOUT) { reload! }
    assert User.new.respond_to?(:age)
  end

  def test_access_to_helpers
    load_environment
    assert_not_nil helper
    assert_instance_of ActionView::Base, helper
    assert_equal 'Once upon a time in a world...',
      helper.truncate('Once upon a time in a world far far away')
  end

  def test_active_record_does_not_panic_when_referencing_an_observed_constant
    add_to_config "config.active_record.observers = :user_observer"

    app_file "app/models/user.rb", <<-MODEL
      class User < ActiveRecord::Base
      end
    MODEL

    app_file "app/models/user_observer.rb", <<-MODEL
      class UserObserver < ActiveRecord::Observer
      end
    MODEL

    load_environment
    assert_nothing_raised { User }
  end
end
