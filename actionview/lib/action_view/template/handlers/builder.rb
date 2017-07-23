# frozen_string_literal: true

module ActionView
  module Template::Handlers
    class Builder
      class_attribute :default_format, default: :xml

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
