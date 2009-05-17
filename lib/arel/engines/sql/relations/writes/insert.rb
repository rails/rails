module Arel
  class Insert < Compound
    def to_sql(formatter = nil)
      [
        "INSERT",
        "INTO #{table_sql}",
        "(#{record.keys.collect { |key| engine.quote_column_name(key.name) }.join(', ')})",
        "VALUES (#{record.collect { |key, value| key.format(value) }.join(', ')})"
      ].join("\n")
    end
  end
end