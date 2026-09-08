# frozen_string_literal: true

module ActionView
  module Template::Handlers
    class Builder # :nodoc:
      class_attribute :default_format, default: :xml

      def call(template, source)
        require "builder" unless defined?(::Builder)
        # the double assignment is to silence "assigned but unused variable" warnings
        "xml = xml = ::Builder::XmlMarkup.new(indent: 2, target: output_buffer.raw);" \
          "#{source};" \
          "output_buffer.to_s"
      end
    end
  end
end
