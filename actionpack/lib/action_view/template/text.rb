module ActionView #:nodoc:
  class Template
    class Text < String #:nodoc:
      HTML = Mime[:html]

      def initialize(string, content_type = HTML)
        super(string.to_s)
        @content_type = Mime[content_type] || content_type
      end

      def details
        {:formats => [@content_type.to_sym]}
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
        [mime_type]
      end

      def partial?
        false
      end
    end
  end
end
