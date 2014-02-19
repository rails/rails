require 'rbconfig'
require 'tempfile'

module Kernel
  # Sets $VERBOSE to nil for the duration of the block and back to its original
  # value afterwards.
  #
  #   silence_warnings do
  #     value = noisy_call # no warning voiced
  #   end
  #
  #   noisy_call # warning voiced
  def silence_warnings
    with_warnings(nil) { yield }
  end

  # Sets $VERBOSE to +true+ for the duration of the block and back to its
  # original value afterwards.
  def enable_warnings
    with_warnings(true) { yield }
  end

  # Sets $VERBOSE for the duration of the block and back to its original
  # value afterwards.
  def with_warnings(flag)
    old_verbose, $VERBOSE = $VERBOSE, flag
    yield
  ensure
    $VERBOSE = old_verbose
  end

  # For compatibility
  def silence_stderr #:nodoc:
    silence_stream(STDERR) { yield }
  end

  # Silences any stream for the duration of the block.
  #
  #   silence_stream(STDOUT) do
  #     puts 'This will never be seen'
  #   end
  #
  #   puts 'But this will'
  #
  # This method is not thread-safe.
  def silence_stream(stream)
    old_stream = stream.dup
    stream.reopen(RbConfig::CONFIG['host_os'] =~ /mswin|mingw/ ? 'NUL:' : '/dev/null')
    stream.sync = true
    yield
  ensure
    stream.reopen(old_stream)
    old_stream.close
  end

  # Blocks and ignores any exception passed as argument if raised within the block.
  #
  #   suppress(ZeroDivisionError) do
  #     1/0
  #     puts 'This code is NOT reached'
  #   end
  #
  #   puts 'This code gets executed and nothing related to ZeroDivisionError was seen'
  def suppress(*exception_classes)
    yield
  rescue Exception => e
    raise unless exception_classes.any? { |cls| e.kind_of?(cls) }
  end

  # Captures the given stream and returns it:
  #
  #   stream = capture(:stdout) { puts 'notice' }
  #   stream # => "notice\n"
  #
  #   stream = capture(:stderr) { warn 'error' }
  #   stream # => "error\n"
  #
  # even for subprocesses:
  #
  #   stream = capture(:stdout) { system('echo notice') }
  #   stream # => "notice\n"
  #
  #   stream = capture(:stderr) { system('echo error 1>&2') }
  #   stream # => "error\n"
  def capture(stream)
    stream = stream.to_s
    captured_stream = Tempfile.new(stream)
    stream_io = eval("$#{stream}")
    origin_stream = stream_io.dup
    stream_io.reopen(captured_stream)

    yield

    stream_io.rewind
    return captured_stream.read
  ensure
    captured_stream.unlink
    stream_io.reopen(origin_stream)
  end
  alias :silence :capture

  # Silences both STDOUT and STDERR, even for subprocesses.
  #
  #   quietly { system 'bundle install' }
  #
  # This method is not thread-safe.
  def quietly
    silence_stream(STDOUT) do
      silence_stream(STDERR) do
        yield
      end
    end
  end
end
