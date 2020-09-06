# frozen_string_literal: true

module ActionView
  module Template::Handlers
    class Builder
      class_attribute :default_format, default: :xml

      def call(template, source)
        require_engine
        'xml = ::Builder::XmlMarkup.new(:indent => 2);' \
          'self.output_buffer = xml.target!;' +
          source +
          ';xml.target!;'
      end

      private
        def require_engine # :doc:
          @required ||= begin
            require 'builder'
            true
          end
        end
    end
  end
end
