require 'action_dispatch/journey/visitors'
require 'action_dispatch/internal/constants'

module ActionDispatch
  module Journey # :nodoc:
    module Nodes # :nodoc:
      class Node # :nodoc:
        include Enumerable

        attr_reader :left
        attr_accessor :memo

        def initialize(left)
          @left = left
          @memo = nil
        end

        def left=(left)
          @name = nil
          @left = left
        end

        def each(&block)
          Visitors::Each.new(block).accept(self)
        end

        def to_s
          Visitors::String.new.accept(self)
        end

        def to_dot
          Visitors::Dot.new.accept(self)
        end

        def to_sym
          name.to_sym
        end

        OMIT_FROM_NAME = '*:'.freeze
        private_constant :OMIT_FROM_NAME

        def name
          @name ||= left.tr(OMIT_FROM_NAME, Strings::EMPTY)
        end

        def type
          raise NotImplementedError
        end

        def symbol?; false; end
        def literal?; false; end
      end

      class Terminal < Node # :nodoc:
        alias :symbol :left
      end

      class Literal < Terminal # :nodoc:
        def literal?; true; end
        def type; :LITERAL; end
      end

      class Dummy < Literal # :nodoc:
        def initialize(x = Object.new)
          super
        end

        def literal?; false; end
      end

      class Slash < Terminal
        def type; :SLASH; end
      end

      class Dot < Terminal
        def type; :DOT; end
      end

      class Symbol < Terminal # :nodoc:
        attr_accessor :regexp
        alias :symbol :regexp

        DEFAULT_EXP = /[^\.\/\?]+/
        def initialize(left)
          super
          @regexp = DEFAULT_EXP
        end

        def default_regexp?
          regexp == DEFAULT_EXP
        end

        def type; :SYMBOL; end

        def symbol?; true; end
      end

      class Unary < Node # :nodoc:
        def children; [left] end
      end

      class Group < Unary # :nodoc:
        def type; :GROUP; end
      end

      class Star < Unary # :nodoc:
        def type; :STAR; end

        def name
          left.name.tr '*:', ''
        end
      end

      class Binary < Node # :nodoc:
        attr_accessor :right

        def initialize(left, right)
          super(left)
          @right = right
        end

        def children; [left, right] end
      end

      class Cat < Binary # :nodoc:
        def type; :CAT; end
      end

      class Or < Node # :nodoc:
        attr_reader :children

        def initialize(children)
          @children = children
        end

        def type; :OR; end
      end
    end
  end
end
