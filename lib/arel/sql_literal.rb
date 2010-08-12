module Arel
  class SqlLiteral < Nodes::SqlLiteral
    def initialize string
      warn "#{caller.first} should use Nodes::SqlLiteral"
      super
    end
  end
end
