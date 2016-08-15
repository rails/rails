require "abstract_unit"
require "active_support/core_ext/kernel"

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

  def test_class_eval
    o = Object.new
    class << o; @x = 1; end
    assert_equal 1, o.class_eval { @x }
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
