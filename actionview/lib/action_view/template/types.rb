# frozen_string_literal: true

require "active_support/core_ext/module/attribute_accessors"

module ActionView
  class Template # :nodoc:
    module Types
      class Type
        SET = Struct.new(:symbols).new([ :html, :text, :js, :css, :xml, :json ])

        def self.[](type)
          if type.is_a?(self)
            type
          else
            new(type)
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

      class << self
        attr_accessor :type_klass

        def delegate_to(klass)
          self.type_klass = klass
        end

        def [](type)
          type_klass[type]
        end

        def symbols
          type_klass::SET.symbols
        end
      end

      delegate_to Type
    end
  end
end
