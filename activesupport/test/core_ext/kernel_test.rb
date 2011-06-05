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


  def test_silence_stderr
    old_stderr_position = STDERR.tell
    silence_stderr { STDERR.puts 'hello world' }
    assert_equal old_stderr_position, STDERR.tell
  rescue Errno::ESPIPE
    # Skip if we can't STDERR.tell
  end

  def test_silence_stderr_with_return_value
    assert_equal 1, silence_stderr { 1 }
  end

  def test_singleton_class
    o = Object.new
    assert_equal class << o; self end, o.singleton_class
  end

  def test_class_eval
    o = Object.new
    class << o; @x = 1; end
    assert_equal 1, o.class_eval { @x }
  end

  def test_capture
    assert_equal 'STDERR', capture(:stderr) {$stderr.print 'STDERR'}
    assert_equal 'STDOUT', capture(:stdout) {print 'STDOUT'}
  end

  def test_require_library_or_gem_deprecated
    assert_deprecated do
      require_library_or_gem 'multi_json'
    end
  end
end

class KernelSuppressTest < Test::Unit::TestCase
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
