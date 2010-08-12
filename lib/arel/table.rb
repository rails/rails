module Arel
  class Table
    @engine = nil
    class << self; attr_accessor :engine; end

    def initialize table_name, engine = Table.engine
      @table_name = table_name
      @engine     = engine
    end

    def [] attribute
      raise attribute
    end
  end
end
