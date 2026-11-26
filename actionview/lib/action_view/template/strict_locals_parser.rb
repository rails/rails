# frozen_string_literal: true

module ActionView
  class Template
    module StrictLocalsParser # :nodoc:
      STRICT_LOCALS_REGEX = /\#\s+locals:\s+\((.*?)\)(?=\s*-?%>|\s*$)/m # :nodoc:
      private_constant :STRICT_LOCALS_REGEX

      def self.extract!(source)
        source.sub!(STRICT_LOCALS_REGEX, "")
        strict_locals = $1&.rstrip
        return if strict_locals.nil?

        # Use the same fallback encoding as Template#encode!.
        if strict_locals.encoding == Encoding::BINARY
          strict_locals.force_encoding(Encoding.default_external)
        end

        strict_locals.blank? ? "**nil" : strict_locals
      end

      def self.block_parameter?(method_arguments)
        return false unless method_arguments.include?("&")

        require "prism"

        source = "def template(#{method_arguments}); end"
        !Prism.parse(source, encoding: source.encoding).value.statements.body.first.parameters&.block.nil?
      end
    end
  end
end
