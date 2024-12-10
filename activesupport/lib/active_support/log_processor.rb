# frozen_string_literal: true

module ActiveSupport
  module LogProcessor # :nodoc:
    attr_accessor :processors

    def self.extended(base)
      base.processors = []
    end

    def initialize(*args, **kwargs)
      super

      self.processors = []
    end

    private
      def format_message(severity, datetime, progname, msg)
        processors.flatten.reverse_each do |processor|
          msg = processor.call(msg, self)
        end

        super(severity, datetime, progname, msg)
      end
  end
end
