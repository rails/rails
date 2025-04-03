# frozen_string_literal: true

require "abstract_unit"
require "env_helpers"
require "rails/command"
require "rails/commands/console/console_command"

class Rails::ConsoleTest < ActiveSupport::TestCase
  include EnvHelpers

  class FakeConsole
    def self.started?
      @started
    end

    def self.start
      @started = true
    end
  end

  def setup
    @prev_rails_env = Rails.env
  end

  def teardown
    Rails.env = @prev_rails_env
  end

  def test_sandbox_option
    console = Rails::Console.new(app, parse_arguments(["--sandbox"]))
    assert_predicate console, :sandbox?
  end

  def test_short_version_of_sandbox_option
    console = Rails::Console.new(app, parse_arguments(["-s"]))
    assert_predicate console, :sandbox?
  end

  def test_no_options
    console = Rails::Console.new(app, parse_arguments([]))
    assert_not_predicate console, :sandbox?
  end

  def test_start
    start

    assert_predicate app.console, :started?
    assert_match(/Loading \w+ environment \(Rails/, output)
  end

  def test_start_with_sandbox
    start ["--sandbox"]

    assert_predicate app.console, :started?
    assert app.sandbox
    assert_match(/Loading \w+ environment in sandbox \(Rails/, output)
  end

  def test_console_with_environment
    start ["-e", "production"]
    assert_match(/\sproduction\s/, output)
  end

  def test_console_defaults_to_IRB
    app = build_app(nil)
    assert_equal "IRB", Rails::Console.new(app).console.name
  end

  def test_prompt_env_colorization
    app = build_app(nil)
    irb_console = Rails::Console.new(app).console
    red = "\e[31m"
    blue = "\e[34m"
    magenta = "\e[35m"
    clear = "\e[0m"

    Rails.env = "development"
    assert_equal("#{blue}dev#{clear}", irb_console.colorized_env)

    Rails.env = "test"
    assert_equal("#{blue}test#{clear}", irb_console.colorized_env)

    Rails.env = "production"
    assert_equal("#{red}prod#{clear}", irb_console.colorized_env)

    Rails.env = "custom_env"
    assert_equal("#{magenta}custom_env#{clear}", irb_console.colorized_env)
  end

  def test_default_environment_with_no_rails_env
    with_rails_env nil do
      start
      assert_match(/\sdevelopment\s/, output)
    end
  end

  def test_default_environment_with_rails_env
    with_rails_env "special-production" do
      start
      assert_match(/\sspecial-production\s/, output)
    end
  end

  def test_default_environment_with_rack_env
    with_rack_env "production" do
      start
      assert_match(/\sproduction\s/, output)
    end
  end

  def test_e_option
    start ["-e", "special-production"]
    assert_match(/\sspecial-production\s/, output)
  end

  def test_e_option_is_properly_expanded
    start ["-e", "prod"]
    assert_match(/\sproduction\s/, output)
  end

  def test_environment_option
    start ["--environment=special-production"]
    assert_match(/\sspecial-production\s/, output)
  end

  def test_rails_env_is_dev_when_environment_option_is_dev_and_dev_env_is_present
    Rails::Command::ConsoleCommand.class_eval do
      alias_method :old_environments, :available_environments

      define_method :available_environments do
        ["dev"]
      end
    end

    assert_match("dev", parse_arguments(["-e", "dev"])[:environment])
  ensure
    Rails::Command::ConsoleCommand.class_eval do
      undef_method :available_environments
      alias_method :available_environments, :old_environments
      undef_method :old_environments
    end
  end

  attr_reader :output
  private :output

  private
    def start(argv = [])
      rails_console = Rails::Console.new(app, parse_arguments(argv))
      @output = capture(:stdout) { rails_console.start }
    end

    def app
      @app ||= build_app(FakeConsole)
    end

    def build_app(console)
      mocked_app = Class.new do
        attr_accessor :sandbox
        attr_reader :console, :disable_sandbox, :sandbox_by_default

        def initialize(console)
          @console = console
        end

        def config
          self
        end

        def load_console
        end
      end
      mocked_app.new(console)
    end

    def parse_arguments(args)
      Rails::Command::ConsoleCommand.new([], args).options
    end
end
