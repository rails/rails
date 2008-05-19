module Arel
  class Insert < Compound
    attr_reader :record

    def initialize(relation, record)
      @relation, @record = relation, record.bind(relation)
    end

    def to_sql(formatter = nil)
      [
        "INSERT",
        "INTO #{table_sql}",
        "(#{record.keys.collect(&:to_sql).join(', ')})",
        "VALUES (#{record.collect { |key, value| key.format(value) }.join(', ')})"
      ].join("\n")
    end
    
    def call(connection = engine.connection)
      connection.insert(to_sql)
    end
    
    def ==(other)
      Insert   === other         and
      relation    == other.relation and
      record      == other.record
    end
  end
end