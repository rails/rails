# frozen_string_literal: true

require "isolation/abstract_unit"
require "console_helpers"

class ConsoleTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::Isolation

  def setup
    build_app
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

  def test_app_can_access_path_helper_method
    app_file "config/routes.rb", <<-RUBY
      Rails.application.routes.draw do
        get 'foo', to: 'foo#index'
      end
    RUBY

    load_environment
    console_session = irb_context.app
    assert_equal "/foo", console_session.foo_path
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
    ActiveSupport::Reloader.to_complete { a = b = c = 1 }
    ActiveSupport::Reloader.to_complete { b = c = 2 }
    ActiveSupport::Reloader.to_prepare { c = 3 }

    irb_context.reload!(false)

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
    irb_context.reload!(false)
    assert User.new.respond_to?(:age)
  end

  def test_access_to_helpers
    load_environment
    helper = irb_context.helper
    assert_not_nil helper
    assert_instance_of ActionView::Base, helper
    assert_equal "Once upon a time in a world...",
      helper.truncate("Once upon a time in a world far far away")
  end
end

class FullStackConsoleTest < ActiveSupport::TestCase
  include ConsoleHelpers

  def setup
    skip "PTY unavailable" unless available_pty?

    build_app
    app_file "app/models/post.rb", <<-CODE
      class Post < ActiveRecord::Base
      end
    CODE
    system "#{app_path}/bin/rails runner 'Post.connection.create_table :posts'"

    @master, @slave = PTY.open
  end

  def teardown
    teardown_app
  end

  def write_prompt(command, expected_output = nil)
    @master.puts command
    assert_output command, @master
    assert_output expected_output, @master if expected_output
    assert_output "> ", @master
  end

  def spawn_console(options)
    Process.spawn(
      "#{app_path}/bin/rails console #{options}",
      in: @slave, out: @slave, err: @slave
    )

    assert_output "> ", @master, 30
  end

  def test_sandbox
    spawn_console("--sandbox")

    write_prompt "Post.count", "=> 0"
    write_prompt "Post.create"
    write_prompt "Post.count", "=> 1"
    @master.puts "quit"

    spawn_console("--sandbox")

    write_prompt "Post.count", "=> 0"
    write_prompt "Post.transaction { Post.create; raise }"
    write_prompt "Post.count", "=> 0"
    @master.puts "quit"
  end

  def test_environment_option_and_irb_option
    spawn_console("test -- --verbose")

    write_prompt "a = 1", "a = 1"
    write_prompt "puts Rails.env", "puts Rails.env\r\ntest"
    @master.puts "quit"
  end
end
