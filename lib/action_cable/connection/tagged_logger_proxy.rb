module ActionCable
  module Connection
    class TaggedLoggerProxy

      def initialize(logger, tags:)
        @logger = logger
        @tags = tags.flatten
      end

      def info(message)
        log :info, message
      end

      def error(message)
        log :error, message
      end

      def add_tags(*tags)
        @tags += tags.flatten
        @tags = @tags.uniq
      end

      protected
        def log(type, message)
          @logger.tagged(*@tags) { @logger.send type, message }
        end

    end
  end
end
