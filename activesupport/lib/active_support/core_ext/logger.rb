require 'logger'

module ActiveSupport
  module InitializeWithKwargs
    if RUBY_VERSION < '2.4'.freeze
      def initialize(*args, level: Logger::DEBUG, **kwargs)
        super(*args)

        self.level           = level
        self.progname        = kwargs[:progname]
        self.datetime_format = kwargs[:datetime_format]
        self.formatter       = kwargs[:formatter]
      end
    end
  end
end

Logger.prepend(ActiveSupport::InitializeWithKwargs)
