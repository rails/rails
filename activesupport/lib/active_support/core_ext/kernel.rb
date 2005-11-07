class Object
  # A Ruby-ized realization of the K combinator, courtesy of Mikael Brockman.
  #
  #   def foo
  #     returning values = [] do
  #       values << 'bar'
  #       values << 'baz'
  #     end
  #   end
  #
  #   foo # => ['bar', 'baz']
  #
  def returning(value)
    yield
    value
  end
  
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

  # Makes backticks behave (somewhat more) similarly on all platforms.
  # On win32 `nonexistent_command` raises Errno::ENOENT; on Unix, the
  # spawned shell prints a message to stderr and sets $?.  We emulate
  # Unix on the former but not the latter.
  def `(command) #:nodoc:
    super
  rescue Errno::ENOENT => e
    STDERR.puts "#$0: #{e}"
  end
  
  # Method that requires a library, ensuring that rubygems is loaded
  def require_library_or_gem(library_name)
    begin
      require library_name
    rescue LoadError => cannot_require
      # 1. Requiring the module is unsuccessful, maybe it's a gem and nobody required rubygems yet. Try.
      begin
        require 'rubygems'
      rescue LoadError => rubygems_not_installed
        raise cannot_require
      end
      # 2. Rubygems is installed and loaded. Try to load the library again
      begin
        require library_name
      rescue LoadError => gem_not_installed
        raise cannot_require
      end
    end
  end


end
