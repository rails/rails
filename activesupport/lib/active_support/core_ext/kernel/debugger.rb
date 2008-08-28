module Kernel
  unless respond_to?(:debugger)
    # Starts a debugging session if ruby-debug has been loaded (call script/server --debugger to do load it).
    def debugger
      Rails.logger.info "\n***** Debugger requested, but was not available: Start server with --debugger to enable *****\n"
    end
  end

  def breakpoint
    Rails.logger.info "\n***** The 'breakpoint' command has been renamed 'debugger' -- please change *****\n"
    debugger
  end
end
