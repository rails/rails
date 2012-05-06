require 'abstract_unit'
require 'rails/commands/console'

class Rails::ConsoleTest < ActiveSupport::TestCase
  class FakeConsole
  end

  def setup
  end

  def test_sandbox_option
    console = Rails::Console.new(app, ["--sandbox"])
    assert console.sandbox?
  end

  def test_short_version_of_sandbox_option
    console = Rails::Console.new(app, ["-s"])
    assert console.sandbox?
  end

  def test_debugger_option
    console = Rails::Console.new(app, ["--debugger"])
    assert console.debugger?
  end

  def test_no_options
    console = Rails::Console.new(app, [])
    assert !console.debugger?
    assert !console.sandbox?
  end

  def test_start
    app.expects(:sandbox=).with(nil)
    FakeConsole.expects(:start)

    start

    assert_match /Loading \w+ environment \(Rails/, output
  end

  def test_start_with_debugger
    app.expects(:sandbox=).with(nil)
    rails_console.expects(:require_debugger).returns(nil)
    FakeConsole.expects(:start)

    start ["--debugger"]
  end

  def test_start_with_sandbox
    app.expects(:sandbox=).with(true)
    FakeConsole.expects(:start)

    start ["--sandbox"]

    assert_match /Loading \w+ environment in sandbox \(Rails/, output
  end

  def test_console_with_environment
    app.expects(:sandbox=).with(nil)
    FakeConsole.expects(:start)

    start ["-e production"]

    assert_match /production/, output
  end

  def test_console_with_rails_environment
    app.expects(:sandbox=).with(nil)
    FakeConsole.expects(:start)

    start ["RAILS_ENV=production"]

    assert_match /production/, output
  end


  def test_console_defaults_to_IRB
    config = mock("config", :console => nil)
    app = mock("app", :config => config)
    app.expects(:load_console).returns(nil)

    assert_equal IRB, Rails::Console.new(app).console
  end

  private

  attr_reader :output

  def rails_console
    @rails_console ||= Rails::Console.new(app)
  end

  def start(argv = [])
    rails_console.stubs(:arguments => argv)
    @output = output = capture(:stdout) { rails_console.start }
  end

  def app
    @app ||= begin
      config = mock("config", :console => FakeConsole)
      app = mock("app", :config => config)
      app.expects(:load_console)
      app
    end
  end
end
