module ActionView
  module Template::Handlers
    class Builder
      # Default format used by Builder.
      class_attribute :default_format
      self.default_format = :xml

      def call(template)
        require_engine
        "xml = ::Builder::XmlMarkup.new(:indent => 2);" \
          "self.output_buffer = xml.target!;" +
          template.source +
          ";xml.target!;"
      end

      private

        def require_engine # :doc:
          @required ||= begin
            require "builder"
            true
          end
        end
    end
  end
end
