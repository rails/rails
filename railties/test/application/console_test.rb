# frozen_string_literal: true

require "tempfile"

require "isolation/abstract_unit"
require "console_helpers"

class FullStackConsoleTest < ActiveSupport::TestCase
  include ConsoleHelpers

  def setup
    skip "PTY unavailable" unless available_pty?

    build_app
    app_file "app/models/post.rb", <<-CODE
      class Post < ActiveRecord::Base
      end
    CODE
    system "#{app_path}/bin/rails runner 'Post.lease_connection.create_table :posts'"

    @primary, @replica = PTY.open
  end

  def teardown
    teardown_app
  end

  def write_prompt(command, expected_output = nil, prompt: "> ")
    @primary.puts command
    assert_output command, @primary
    assert_output expected_output, @primary, 100 if expected_output
    assert_output prompt, @primary
  end

  def spawn_console(options, wait_for_prompt: true, env: {})
    # Test should not depend on user's irbrc file
    home_tmp_dir = Dir.mktmpdir

    pid = Process.spawn(
      { "TERM" => "dumb", "HOME" => home_tmp_dir }.merge(env),
      "#{app_path}/bin/rails console #{options}",
      in: @replica, out: @replica, err: @replica
    )

    if wait_for_prompt
      assert_output "> ", @primary, 30
    end

    pid
  ensure
    FileUtils.remove_entry(home_tmp_dir)
  end

  def test_sandbox
    options = "--sandbox"
    spawn_console(options)

    write_prompt "Post.count", "=> 0"
    write_prompt "Post.create"
    write_prompt "Post.count", "=> 1"
    @primary.puts "quit"

    spawn_console(options)

    write_prompt "Post.count", "=> 0"
    write_prompt "Post.transaction { Post.create; raise }"
    write_prompt "Post.count", "=> 0"
    @primary.puts "quit"
  end

  def test_sandbox_when_sandbox_is_disabled
    add_to_config <<-RUBY
      config.disable_sandbox = true
    RUBY

    output = `#{app_path}/bin/rails console --sandbox`

    assert_includes output, "sandbox mode is disabled"
    assert_equal 1, $?.exitstatus
  end

  def test_sandbox_by_default
    add_to_config <<-RUBY
      config.sandbox_by_default = true
    RUBY

    options = "-e production -- --verbose"
    spawn_console(options)

    write_prompt "puts Rails.application.sandbox", "puts Rails.application.sandbox\r\ntrue"
    @primary.puts "quit"
  end

  def test_sandbox_by_default_with_no_sandbox
    add_to_config <<-RUBY
      config.sandbox_by_default = true
    RUBY

    options = "-e production --no-sandbox -- --verbose"
    spawn_console(options)

    write_prompt "puts Rails.application.sandbox", "puts Rails.application.sandbox\r\nfalse"
    @primary.puts "quit"
  end

  def test_sandbox_by_default_with_development_environment
    add_to_config <<-RUBY
      config.sandbox_by_default = true
    RUBY

    options = "-- --verbose"
    spawn_console(options)

    write_prompt "puts Rails.application.sandbox", "puts Rails.application.sandbox\r\nfalse"
    @primary.puts "quit"
  end

  def test_prompt_is_properly_set
    options = "-e test -- --verbose"
    spawn_console(options)

    write_prompt "a = 1", "a = 1", prompt: "app-template(test)>"
  end

  def test_prompt_allows_changing_irb_name
    options = "-e test -- --verbose"
    spawn_console(options)

    write_prompt "conf.irb_name = 'foo'"
    write_prompt "a = 1", "a = 1", prompt: "foo(test)>"
    @primary.puts "quit"
  end

  def test_environment_option_and_irb_option
    options = "-e test -- --verbose"
    spawn_console(options)

    write_prompt "a = 1", "a = 1"
    write_prompt "puts Rails.env", "puts Rails.env\r\ntest"
    @primary.puts "quit"
  end

  def test_production_console_prompt
    options = "-e production"
    spawn_console(options)

    write_prompt "123", prompt: "app-template(prod)>"
  end

  def test_development_console_prompt
    options = "-e development"
    spawn_console(options)

    write_prompt "123", prompt: "app-template(dev)> "
  end

  def test_test_console_prompt
    options = "-e test"
    spawn_console(options)

    write_prompt "123", prompt: "app-template(test)> "
  end

  def test_helper_helper_method
    spawn_console("-e development")

    write_prompt "helper.truncate('Once upon a time in a world far far away')", "Once upon a time in a world..."
  end

  def test_controller_helper_method
    spawn_console("-e development")

    write_prompt "controller.class.name", "ApplicationController"
  end

  def test_new_session_helper_method
    spawn_console("-e development")

    write_prompt "new_session.class.name", "ActionDispatch::Integration::Session"
  end

  def test_app_helper_method
    app_file "config/routes.rb", <<-RUBY
      Rails.application.routes.draw do
        get 'foo', to: 'foo#index'
      end
    RUBY

    spawn_console("-e development")

    write_prompt "app.foo_path", "/foo"
  end

  def test_app_routes_are_loaded
    app_file "config/routes.rb", <<-RUBY
      Rails.application.routes.draw do
        get 'foo', to: 'foo#index'
      end
    RUBY

    spawn_console("-e development")

    write_prompt "app.methods.grep(/foo_path/)", "[:foo_path]"
  end

  def test_reload_command_fires_preparation_and_cleanup_callbacks
    options = "-e development"
    spawn_console(options)

    write_prompt "a = b = c = nil"
    write_prompt "ActiveSupport::Reloader.to_complete { a = b = c = 1 }"
    write_prompt "ActiveSupport::Reloader.to_complete { b = c = 2 }"
    write_prompt "ActiveSupport::Reloader.to_prepare { c = 3 }"
    write_prompt "reload!", "Reloading...\r\n"
    write_prompt "a", "=> 1"
    write_prompt "b", "=> 2"
    write_prompt "c", "=> 3"
  end

  def test_reload_command_reload_constants
    app_file "app/models/user.rb", <<-MODEL
      class User
        attr_accessor :name
      end
    MODEL

    options = "-e development"
    # Now the User model has only one attribute called `name`
    spawn_console(options)


    write_prompt "User.new.respond_to?(:age)", "=> false"

    # This will be loaded after the reload! command is executed
    app_file "app/models/user.rb", <<-MODEL
      class User
        attr_accessor :name, :age
      end
    MODEL

    write_prompt "reload!", "Reloading...\r\n"
    write_prompt "User.new.respond_to?(:age)", "=> true"
  end

  def test_console_respects_user_defined_prompt_mode
    irbrc = Tempfile.new("irbrc")
    irbrc.write <<-RUBY
      IRB.conf[:PROMPT_MODE] = :SIMPLE
    RUBY
    irbrc.close

    options = "-e test"
    spawn_console(options, env: { "IRBRC" => irbrc.path })

    write_prompt "123", prompt: ">> "
  ensure
    File.unlink(irbrc)
  end

  def test_console_disables_IRB_auto_completion_in_non_local
    options = "-e production -- --verbose"
    spawn_console(options)

    write_prompt "IRB.conf[:USE_AUTOCOMPLETE]", "IRB.conf[:USE_AUTOCOMPLETE]\r\n=> false"
  end

  def test_console_accepts_override_on_IRB_auto_completion_flag
    options = "-e production -- --verbose"
    spawn_console(options, env: { "IRB_USE_AUTOCOMPLETE" => "true" })

    write_prompt "IRB.conf[:USE_AUTOCOMPLETE]", "IRB.conf[:USE_AUTOCOMPLETE]\r\n=> true"
  end

  def test_console_doesnt_disable_IRB_auto_completion_in_local
    options = "-e development -- --verbose"
    spawn_console(options)

    write_prompt "IRB.conf[:USE_AUTOCOMPLETE]", "IRB.conf[:USE_AUTOCOMPLETE]\r\n=> true"
  end
end
