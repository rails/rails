module Arel
  class Table
    @engine = nil
    class << self; attr_accessor :engine; end

    def initialize name, engine = Table.engine
      @name   = name
      @engine = engine
    end

    def columns
      @engine.connection.columns(@name, "#{@name} Columns").map do |column|
        Attributes.for(column).new self, column.name, column
      end
    end

    def [] name
      name = name.to_s
      columns.find { |column| column.name == name }
    end
  end
end
