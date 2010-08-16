module Arel
  class Table
    include Arel::Crud

    @engine = nil
    class << self; attr_accessor :engine; end

    attr_reader :name, :engine

    def initialize name, engine = Table.engine
      @name    = name
      @engine  = engine
      @engine  = engine[:engine] if Hash === engine
      @columns = nil
    end

    def tm
      SelectManager.new(@engine).from(self)
    end

    def where condition
      tm.where condition
    end

    def project thing
      tm.project thing
    end

    def columns
      @columns ||= @engine.connection.columns(@name, "#{@name} Columns").map do |column|
        Attributes.for(column).new self, column.name, column
      end
    end

    def [] name
      name = name.to_s
      columns.find { |column| column.name == name }
    end
  end
end
