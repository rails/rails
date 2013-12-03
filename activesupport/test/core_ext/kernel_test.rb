require 'abstract_unit'
require 'active_support/core_ext/kernel'

class KernelTest < ActiveSupport::TestCase

  def test_silence_warnings
    silence_warnings { assert_nil $VERBOSE }
    assert_equal 1234, silence_warnings { 1234 }
  end

  def test_silence_warnings_verbose_invariant
    old_verbose = $VERBOSE
    silence_warnings { raise }
    flunk
  rescue
    assert_equal old_verbose, $VERBOSE
  end

  def test_enable_warnings
    enable_warnings { assert_equal true, $VERBOSE }
    assert_equal 1234, enable_warnings { 1234 }
  end

  def test_enable_warnings_verbose_invariant
    old_verbose = $VERBOSE
    enable_warnings { raise }
    flunk
  rescue
    assert_equal old_verbose, $VERBOSE
  end

  def test_silence_stream_is_thread_safe
    $current_stdout = STDOUT.dup
    original_stdout = $current_stdout.inspect

    threads = []
    4.times do |i|
      threads << Thread.new(i) do
        silence_stream($current_stdout) do
          $current_stdout.puts "hello silent world"
          silence_stream($current_stdout) do
            $current_stdout.puts "Hello inner silent world"
          end
        end
      end
    end

    assert_nothing_raised { threads.each(&:join) }

    assert_equal $current_stdout.inspect, original_stdout
  ensure
    $current_stdout = nil
  end

  def test_capture_is_thread_safe
    $stdout_test = STDOUT.dup
    original_stdout = $stdout_test.inspect

    threads = []
    4.times do |i|
      threads << Thread.new(i) do
        capture(:stdout_test) { $stdout_test.print "hello" }
        capture(:stdout_test) { $stdout_test.print "hello also" }
      end
    end

    assert_nothing_raised { threads.each(&:join) }

    assert_equal $stdout_test.inspect, original_stdout
  ensure
    $stdout_test = nil
  end

  def test_silence_stderr
    old_stderr_position = STDERR.tell
    silence_stderr { STDERR.puts 'hello world' }
    assert_equal old_stderr_position, STDERR.tell
  rescue Errno::ESPIPE
    # Skip if we can't STDERR.tell
  end

  def test_quietly
    old_stdout_position, old_stderr_position = STDOUT.tell, STDERR.tell
    quietly do
      puts 'see me, feel me'
      STDERR.puts 'touch me, heal me'
    end
    assert_equal old_stdout_position, STDOUT.tell
    assert_equal old_stderr_position, STDERR.tell
  rescue Errno::ESPIPE
    # Skip if we can't STDERR.tell
  end

  def test_silence_stderr_with_return_value
    assert_equal 1, silence_stderr { 1 }
  end

  def test_class_eval
    o = Object.new
    class << o; @x = 1; end
    assert_equal 1, o.class_eval { @x }
  end

  def test_capture
    assert_equal 'STDERR', capture(:stderr) { $stderr.print 'STDERR' }
    assert_equal 'STDOUT', capture(:stdout) { print 'STDOUT' }
    assert_equal "STDERR\n", capture(:stderr) { system('echo STDERR 1>&2') }
    assert_equal "STDOUT\n", capture(:stdout) { system('echo STDOUT') }
  end
end

class KernelSuppressTest < ActiveSupport::TestCase
  def test_reraise
    assert_raise(LoadError) do
      suppress(ArgumentError) { raise LoadError }
    end
  end

  def test_suppression
    suppress(ArgumentError) { raise ArgumentError }
    suppress(LoadError) { raise LoadError }
    suppress(LoadError, ArgumentError) { raise LoadError }
    suppress(LoadError, ArgumentError) { raise ArgumentError }
  end
end

class MockStdErr
  attr_reader :output
  def puts(message)
    @output ||= []
    @output << message
  end

  def info(message)
    puts(message)
  end

  def write(message)
    puts(message)
  end
end

class KernelDebuggerTest < ActiveSupport::TestCase
  def test_debugger_not_available_message_to_stderr
    old_stderr = $stderr
    $stderr = MockStdErr.new
    debugger
    assert_match(/Debugger requested/, $stderr.output.first)
  ensure
    $stderr = old_stderr
  end

  def test_debugger_not_available_message_to_rails_logger
    rails = Class.new do
      def self.logger
        @logger ||= MockStdErr.new
      end
    end
    Object.const_set(:Rails, rails)
    debugger
    assert_match(/Debugger requested/, rails.logger.output.first)
  ensure
    Object.send(:remove_const, :Rails)
  end
end
