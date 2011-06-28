module Kernel
  unless respond_to?(:debugger)
    # Starts a debugging session if ruby-debug has been loaded (call rails server --debugger to do load it).
    def debugger
      message = "\n***** Debugger requested, but was not available (ensure ruby-debug is listed in Gemfile/installed as gem): Start server with --debugger to enable *****\n"
      defined?(Rails) ? Rails.logger.info(message) : $stderr.puts(message)
    end
    alias breakpoint debugger unless respond_to?(:breakpoint)
  end
end
