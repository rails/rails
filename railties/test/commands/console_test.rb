require 'abstract_unit'
require 'env_helpers'
require 'rails/commands/console'

class Rails::ConsoleTest < ActiveSupport::TestCase
  include EnvHelpers

  class FakeConsole
    def self.start; end
  end

  def test_sandbox_option
    console = Rails::Console.new(app, parse_arguments(["--sandbox"]))
    assert console.sandbox?
  end

  def test_short_version_of_sandbox_option
    console = Rails::Console.new(app, parse_arguments(["-s"]))
    assert console.sandbox?
  end

  def test_debugger_option
    console = Rails::Console.new(app, parse_arguments(["--debugger"]))
    assert console.debugger?
  end

  def test_no_options
    console = Rails::Console.new(app, parse_arguments([]))
    assert !console.debugger?
    assert !console.sandbox?
  end

  def test_start
    FakeConsole.expects(:start)
    start
    assert_match(/Loading \w+ environment \(Rails/, output)
  end

  def test_start_with_debugger
    rails_console = Rails::Console.new(app, parse_arguments(["--debugger"]))
    rails_console.expects(:require_debugger).returns(nil)

    silence_stream(STDOUT) { rails_console.start }
  end

  def test_start_with_sandbox
    app.expects(:sandbox=).with(true)
    FakeConsole.expects(:start)

    start ["--sandbox"]

    assert_match(/Loading \w+ environment in sandbox \(Rails/, output)
  end

  def test_console_with_environment
    start ["-e production"]
    assert_match(/\sproduction\s/, output)
  end

  def test_console_defaults_to_IRB
    config = mock("config", console: nil)
    app = mock("app", config: config)
    app.expects(:load_console).returns(nil)

    assert_equal IRB, Rails::Console.new(app).console
  end

  def test_default_environment_with_no_rails_env
    with_rails_env nil do
      start
      assert_match(/\sdevelopment\s/, output)
    end
  end

  def test_default_environment_with_rails_env
    with_rails_env 'special-production' do
      start
      assert_match(/\sspecial-production\s/, output)
    end
  end

  def test_default_environment_with_rack_env
    with_rack_env 'production' do
      start
      assert_match(/\sproduction\s/, output)
    end
  end

  def test_e_option
    start ['-e', 'special-production']
    assert_match(/\sspecial-production\s/, output)
  end

  def test_environment_option
    start ['--environment=special-production']
    assert_match(/\sspecial-production\s/, output)
  end

  def test_rails_env_is_production_when_first_argument_is_p
    start ['p']
    assert_match(/\sproduction\s/, output)
  end

  def test_rails_env_is_test_when_first_argument_is_t
    start ['t']
    assert_match(/\stest\s/, output)
  end

  def test_rails_env_is_development_when_argument_is_d
    start ['d']
    assert_match(/\sdevelopment\s/, output)
  end

  private

  attr_reader :output

  def start(argv = [])
    rails_console = Rails::Console.new(app, parse_arguments(argv))
    @output = capture(:stdout) { rails_console.start }
  end

  def app
    @app ||= begin
      config = mock("config", console: FakeConsole)
      app = mock("app", config: config)
      app.stubs(:sandbox=).returns(nil)
      app.expects(:load_console)
      app
    end
  end

  def parse_arguments(args)
    Rails::Console.parse_arguments(args)
  end
end
