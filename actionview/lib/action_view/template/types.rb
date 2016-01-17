require 'set'
require 'active_support/core_ext/module/attribute_accessors'

module ActionView
  class Template
    class Types
      class Type
        SET = Set.new([ :html, :text, :js, :css, :xml, :json ])

        def self.[](type)
          return type if type.is_a?(self)

          if type.is_a?(Symbol) || SET.member?(type.to_s)
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

      cattr_accessor :type_klass

      def self.delegate_to(klass)
        self.type_klass = klass
      end

      delegate_to Type

      def self.[](type)
        type_klass[type]
      end
    end
  end
end
