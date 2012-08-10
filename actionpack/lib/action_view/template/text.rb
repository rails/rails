module ActionView #:nodoc:
  # = Action View Text Template
  class Template
    class Text #:nodoc:
      attr_accessor :mime_type

      def initialize(string, mime_type = nil)
        @string      = string.to_s
        @mime_type   = Mime[mime_type] || mime_type if mime_type
        @mime_type ||= Mime::TEXT
      end

      def identifier
        'text template'
      end

      def inspect
        'text template'
      end

      def to_str
        @string
      end

      def render(*args)
        to_str
      end

      def formats
        [@mime_type.to_sym]
      end
    end
  end
end
