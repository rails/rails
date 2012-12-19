require 'action_dispatch/journey/visitors'

module ActionDispatch
  module Journey
    module Nodes
      class Node # :nodoc:
        include Enumerable

        attr_accessor :left, :memo

        def initialize left
          @left = left
          @memo = nil
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

        def name
          left.tr '*:', ''
        end

        def type
          raise NotImplementedError
        end

        def symbol?; false; end
        def literal?; false; end
      end

      class Terminal < Node
        alias :symbol :left
      end

      class Literal < Terminal
        def literal?; true; end
        def type; :LITERAL; end
      end

      class Dummy < Literal
        def initialize x = Object.new
          super
        end

        def literal?; false; end
      end

      %w{ Symbol Slash Dot }.each do |t|
        class_eval <<-eoruby, __FILE__, __LINE__ + 1
          class #{t} < Terminal;
            def type; :#{t.upcase}; end
          end
        eoruby
      end

      class Symbol < Terminal
        attr_accessor :regexp
        alias :symbol :regexp

        DEFAULT_EXP = /[^\.\/\?]+/
        def initialize left
          super
          @regexp = DEFAULT_EXP
        end

        def default_regexp?
          regexp == DEFAULT_EXP
        end

        def symbol?; true; end
      end

      class Unary < Node
        def children; [left] end
      end

      class Group < Unary
        def type; :GROUP; end
      end

      class Star < Unary
        def type; :STAR; end
      end

      class Binary < Node
        attr_accessor :right

        def initialize left, right
          super(left)
          @right = right
        end

        def children; [left, right] end
      end

      class Cat < Binary
        def type; :CAT; end
      end

      class Or < Node
        attr_reader :children

        def initialize children
          @children = children
        end

        def type; :OR; end
      end
    end
  end
end
