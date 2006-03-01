module Kernel
  # Sets $VERBOSE to nil for the duration of the block and back to its original value afterwards.
  #
  #   silence_warnings do
  #     value = noisy_call # no warning voiced
  #   end
  #
  #   noisy_call # warning voiced
  def silence_warnings
    old_verbose, $VERBOSE = $VERBOSE, nil
    yield
  ensure
    $VERBOSE = old_verbose
  end

  # Sets $VERBOSE to true for the duration of the block and back to its original value afterwards.
  def enable_warnings
    old_verbose, $VERBOSE = $VERBOSE, true
    yield
  ensure
    $VERBOSE = old_verbose
  end

  # Silences stderr for the duration of the block.
  #
  #   silence_stderr do
  #     $stderr.puts 'This will never be seen'
  #   end
  #
  #   $stderr.puts 'But this will'
  def silence_stderr
    old_stderr = STDERR.dup
    STDERR.reopen(RUBY_PLATFORM =~ /mswin/ ? 'NUL:' : '/dev/null')
    STDERR.sync = true
    yield
  ensure
    STDERR.reopen(old_stderr)
  end

  def suppress(*exception_classes)
    begin yield
    rescue Exception => e
      raise unless exception_classes.any? { |cls| e.kind_of?(cls) }
    end
  end
end