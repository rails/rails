# The Journey::Node objects comprise the abstract syntax tree (AST) used by
# Journey for route recognition.
#
# Given the following set of two routes
#
#   get ':action', to: SomeController
#   get 'users/:id', to: 'users#show'
#
# To transition between these states we use an abstract syntax tree made up of
# instances of subclasses of Journey::Nodes::Node. Nodes have "left" and
# "right" parts, with the left representing some content of the node itself and
# the right representing a further expanstion of the syntax tree. The above
# sample route definition produces an AST that has a `Nodes::Or` at the root
# with two `Nodes::Cat` children under it, each reflecting one of the route
# definitions.
#
#   Or
#     Cat
#       left:
#         Slash
#           left: "/"
#       right:
#         Cat
#           left:
#             Symbol:
#               left:   ":action"
#               regexp: /[^\.\/\?]+/
#           right:
#             Group
#               left:
#                 Cat
#                   left:
#                     Dot
#                       left: "."
#               right:
#                 Symbol
#                   left    ":format"
#                   regexp: /[^\.\/\?]+/
#     Cat
#       left:
#         Slash
#           left: "/"
#       right:
#         Cat
#           left:
#             Literal:
#               left: "users"
#           right:
#             Cat
#               left:
#                 Slash
#                   left: "/"
#               Cat
#                 left:
#                   Symbol
#                     left    ":id"
#                     regexp: /[^\.\/\?]+/
#                 right:
#                   Group
#                     left:
#                       Cat
#                         left:
#                           Dot
#                             left: "."
#                     right:
#                       Symbol
#                         left    ":format"
#                         regexp: /[^\.\/\?]+/
#
# From this AST Journey will generate a General Transition Graph in an instance
# of Journey::GTG::TransitionTable. A General Transition Graph is a fancy way
# of saying a state machine where moving from state to state involves regular
# expressions.
#
# The sample routeset about results in this transition table:
#
#   @accepting = {  # an index of which states (by number) are valid final
#     2 => true,    # states. If, after processing the whole AST through these
#     6 => true,    # states the final state is not one of these numbers then
#     7 => true,    # the route recognition fails.
#     9 => true
#   },
#   @memos = {
#     2 => [<#Route>, <#Route>], # lists of routes that match specific state numbers
#     6 => [<#Route>, <#Route>],
#     7 => [<#Route>, <#Route>],
#     9 => [<#Route>, <#Route>],
#   }
#   @regexp_states = { # These regular expressions constrain moving from state to state
#     1 => {
#       /[^\.\/\?]+/ => 2
#     },
#     4 => {
#       /[^\.\/\?]+/ => 6
#     },
#     5 => {
#       /[^\.\/\?]+/ => 7
#     },
#     8 => {
#       /[^\.\/\?]+/ => 9
#     }
#   },
#   @string_states = { # similar to @regexp_states these strings allow calculation to
#     0 => {           # proceed from state to state.
#       "/" => 1
#     },
#     1 => {
#       "users" => 3   # Note that if the path matches "users" while in state number
#     },               # 1 we to state number 3 but 3 is not an 'accepting' state. This
#     2 => {           # matches our intuition that a "users/:id" pattern can't be
#       "." => 4       # satisfied by "users", we need to keep processing the string
#     },               # and extract an ":id" symbol to be accepted as a valid route.
#     3 => {
#       "/" => 5       # This will move us from state 3 ("users") to state 5 ("users/").
#     },               # Then @regexp_states[5] matches any valid :id and will move us to
#     7 => {           # state 7 which is a valid acceptable state.
#       "." => 8
#     }
#   }
#
require 'action_dispatch/journey/visitors'

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

      %w{ Symbol Slash Dot }.each do |t|
        class_eval <<-eoruby, __FILE__, __LINE__ + 1
          class #{t} < Terminal;
            def type; :#{t.upcase}; end
          end
        eoruby
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
