# frozen_string_literal: true

require "action_dispatch/journey/visitors"

module ActionDispatch
  module Journey # :nodoc:
    module Nodes # :nodoc:
      class Node # :nodoc:
        include Enumerable

        attr_accessor :left, :memo

        def initialize(left)
          @left = left
          @memo = nil
        end

        def each(&block)
          Visitors::Each::INSTANCE.accept(self, block)
        end

        def to_s
          Visitors::String::INSTANCE.accept(self, "")
        end

        def to_dot
          Visitors::Dot::INSTANCE.accept(self)
        end

        def to_sym
          name.to_sym
        end

        def name
          -left.tr("*:", "")
        end

        def type
          raise NotImplementedError
        end

        def symbol?; false; end
        def literal?; false; end
        def terminal?; false; end
        def star?; false; end
        def cat?; false; end
        def group?; false; end
      end

      class Terminal < Node # :nodoc:
        alias :symbol :left
        def terminal?; true; end
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

      class Slash < Terminal # :nodoc:
        def type; :SLASH; end
      end

      class Dot < Terminal # :nodoc:
        def type; :DOT; end
      end

      class Symbol < Terminal # :nodoc:
        attr_accessor :regexp
        alias :symbol :regexp
        attr_reader :name

        DEFAULT_EXP = /[^.\/?]+/
        GREEDY_EXP = /(.+)/
        def initialize(left, regexp = DEFAULT_EXP)
          super(left)
          @regexp = regexp
          @name = -left.tr("*:", "")
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
        def group?; true; end
      end

      class Star < Unary # :nodoc:
        attr_accessor :regexp

        def initialize(left)
          super(left)

          # By default wildcard routes are non-greedy and must match something.
          @regexp = /.+?/
        end

        def star?; true; end
        def type; :STAR; end

        def name
          left.name.tr "*:", ""
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
        def cat?; true; end
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
