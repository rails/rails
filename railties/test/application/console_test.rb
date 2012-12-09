require 'isolation/abstract_unit'

class ConsoleTest < ActiveSupport::TestCase
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
    Rails.application.sandbox = sandbox
    Rails.application.load_console
  end

  def irb_context
    Object.new.extend(Rails::ConsoleMethods)
  end

  def test_app_method_should_return_integration_session
    TestHelpers::Rack.send :remove_method, :app
    load_environment
    console_session = irb_context.app
    assert_instance_of ActionDispatch::Integration::Session, console_session
  end

  def test_new_session_should_return_integration_session
    load_environment
    session = irb_context.new_session
    assert_instance_of ActionDispatch::Integration::Session, session
  end

  def test_reload_should_fire_preparation_and_cleanup_callbacks
    load_environment
    a = b = c = nil

    # TODO: These should be defined on the initializer
    ActionDispatch::Reloader.to_cleanup { a = b = c = 1 }
    ActionDispatch::Reloader.to_cleanup { b = c = 2 }
    ActionDispatch::Reloader.to_prepare { c = 3 }

    # Hide Reloading... output
    silence_stream(STDOUT) { irb_context.reload! }

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

    app_file "app/models/user.rb", <<-MODEL
      class User
        attr_accessor :name, :age
      end
    MODEL

    assert !User.new.respond_to?(:age)
    silence_stream(STDOUT) { irb_context.reload! }
    assert User.new.respond_to?(:age)
  end

  def test_access_to_helpers
    load_environment
    helper = irb_context.helper
    assert_not_nil helper
    assert_instance_of ActionView::Base, helper
    assert_equal 'Once upon a time in a world...',
      helper.truncate('Once upon a time in a world far far away')
  end

  def test_with_sandbox
    require 'rails/all'
    value = false

    Class.new(Rails::Railtie) do
      console do |app|
        value = app.sandbox?
      end
    end

    load_environment(true)
    assert value
  end
end
