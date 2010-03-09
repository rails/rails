module ActionView #:nodoc:
  class Template
    class Text < String #:nodoc:
      def initialize(string, content_type = nil)
        super(string.to_s)
        @content_type   = Mime[content_type] || content_type if content_type
        @content_type ||= Mime::TEXT
      end

      def identifier
        'text template'
      end

      def inspect
        'text template'
      end

      def render(*args)
        to_s
      end

      def mime_type
        @content_type
      end

      def formats
        [@content_type.to_sym]
      end

      def partial?
        false
      end
    end
  end
end
