# frozen_string_literal: true
module Arel
  class UpdateManager < Arel::TreeManager
    def initialize
      super
      @ast = Nodes::UpdateStatement.new
      @ctx = @ast
    end

    def take limit
      @ast.limit = Nodes::Limit.new(Nodes.build_quoted(limit)) if limit
      self
    end

    def key= key
      @ast.key = Nodes.build_quoted(key)
    end

    def key
      @ast.key
    end

    def order *expr
      @ast.orders = expr
      self
    end

    ###
    # UPDATE +table+
    def table table
      @ast.relation = table
      self
    end

    def wheres= exprs
      @ast.wheres = exprs
    end

    def where expr
      @ast.wheres << expr
      self
    end

    def set values
      if String === values
        @ast.values = [values]
      else
        @ast.values = values.map { |column,value|
          Nodes::Assignment.new(
            Nodes::UnqualifiedColumn.new(column),
            value
          )
        }
      end
      self
    end
  end
end
