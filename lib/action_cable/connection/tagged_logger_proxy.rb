module ActionCable
  module Connection
    # Allows the use of per-connection tags against the server logger. This wouldn't work using the tradional
    # ActiveSupport::TaggedLogging-enhanced Rails.logger, as that logger will reset the tags between requests.
    # The connection is long-lived, so it needs its own set of tags for its independent duration.
    class TaggedLoggerProxy
      def initialize(logger, tags:)
        @logger = logger
        @tags = tags.flatten
      end

      def add_tags(*tags)
        @tags += tags.flatten
        @tags = @tags.uniq
      end

      %i( debug info warn error fatal unknown ).each do |severity|
        define_method(severity) do |message|
          log severity, message
        end
      end

      protected
        def log(type, message)
          @logger.tagged(*@tags) { @logger.send type, message }
        end
    end
  end
end
