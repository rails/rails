# node
require 'arel/nodes/node'
require 'arel/nodes/select_statement'
require 'arel/nodes/select_core'
require 'arel/nodes/insert_statement'
require 'arel/nodes/update_statement'
require 'arel/nodes/bind_param'

# terminal

require 'arel/nodes/terminal'
require 'arel/nodes/true'
require 'arel/nodes/false'

# unary
require 'arel/nodes/unary'
require 'arel/nodes/grouping'
require 'arel/nodes/ascending'
require 'arel/nodes/descending'
require 'arel/nodes/unqualified_column'
require 'arel/nodes/with'

# binary
require 'arel/nodes/binary'
require 'arel/nodes/equality'
require 'arel/nodes/in' # Why is this subclassed from equality?
require 'arel/nodes/join_source'
require 'arel/nodes/delete_statement'
require 'arel/nodes/table_alias'
require 'arel/nodes/infix_operation'
require 'arel/nodes/over'
require 'arel/nodes/matches'

# nary
require 'arel/nodes/and'

# function
# FIXME: Function + Alias can be rewritten as a Function and Alias node.
# We should make Function a Unary node and deprecate the use of "aliaz"
require 'arel/nodes/function'
require 'arel/nodes/count'
require 'arel/nodes/extract'
require 'arel/nodes/values'
require 'arel/nodes/named_function'

# windows
require 'arel/nodes/window'

# joins
require 'arel/nodes/full_outer_join'
require 'arel/nodes/inner_join'
require 'arel/nodes/outer_join'
require 'arel/nodes/right_outer_join'
require 'arel/nodes/string_join'

require 'arel/nodes/sql_literal'

module Arel
  module Nodes
    class Casted < Arel::Nodes::Node # :nodoc:
      attr_reader :val, :attribute
      def initialize val, attribute
        @val       = val
        @attribute = attribute
        super()
      end

      def nil?; @val.nil?; end

      def eql? other
        self.class == other.class &&
          self.val == other.val &&
          self.attribute == other.attribute
      end
      alias :== :eql?
    end

    class Quoted < Arel::Nodes::Unary # :nodoc:
    end

    def self.build_quoted other, attribute = nil
      case other
      when Arel::Nodes::Node, Arel::Attributes::Attribute, Arel::Table, Arel::Nodes::BindParam, Arel::SelectManager
        other
      else
        case attribute
        when Arel::Attributes::Attribute
          Casted.new other, attribute
        else
          Quoted.new other
        end
      end
    end
  end
end
