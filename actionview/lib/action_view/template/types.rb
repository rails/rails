# frozen_string_literal: true

require "active_support/core_ext/module/attribute_accessors"

module ActionView
  class Template # :nodoc:
    # SimpleType is mostly just a stub implementation for when Action View
    # is used without Action Dispatch.
    class SimpleType # :nodoc:
      @symbols = [ :html, :text, :js, :css, :xml, :json ]
      class << self
        attr_reader :symbols

        def [](type)
          if type.is_a?(self)
            type
          else
            new(type)
          end
        end

        def valid_symbols?(symbols) # :nodoc
          symbols.all? { |s| @symbols.include?(s) }
        end
      end

      attr_reader :symbol

      def initialize(symbol)
        @symbol = symbol.to_sym
      end

      def to_s
        @symbol.to_s
      end
      alias to_str to_s

      def ref
        @symbol
      end
      alias to_sym ref

      def ==(type)
        @symbol == type.to_sym unless type.blank?
      end
    end

    Types = SimpleType # :nodoc:
  end
end
