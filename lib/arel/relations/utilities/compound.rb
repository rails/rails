module Arel
  class Compound < Relation
    attr_reader :relation
    hash_on :relation
    delegate :joins, :join?, :inserts, :taken, :skipped, :name, :aggregation?,
             :column_for, :engine, :table, :table_sql,
             :to => :relation
    
    [:attributes, :wheres, :groupings, :orders].each do |operation_name|
      operation = <<-OPERATION
        def #{operation_name}
          @#{operation_name} ||= relation.#{operation_name}.collect { |o| o.bind(self) }
        end
      OPERATION
      class_eval operation, __FILE__, __LINE__
    end
  end
end