# frozen_string_literal: true

module ActionView
  module Template::Handlers
    class Builder
      class_attribute :default_format, default: :xml

      def call(template, source)
        require_engine
        # the double assignment is to silence "assigned but unused variable" warnings
        "xml = xml = ::Builder::XmlMarkup.new(indent: 2, target: output_buffer.raw);" \
          "#{source};" \
          "output_buffer.to_s"
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
