# frozen_string_literal: true

require "prism"

module ActionView
  class Template
    module StrictLocalsParser # :nodoc:
      def self.block_parameter?(method_arguments)
        source = "def template(#{method_arguments}); end"
        !Prism.parse(source, encoding: source.encoding).value.statements.body.first.parameters&.block.nil?
      end
    end
  end
end
