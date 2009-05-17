module Arel
  class Compound < Relation
    attr_reader :relation
    hash_on :relation
    delegate :joins, :join?, :inserts, :taken, :skipped, :name, :externalizable?,
             :column_for, :engine,
             :to => :relation

    [:attributes, :wheres, :groupings, :orders].each do |operation_name|
      class_eval <<-OPERATION, __FILE__, __LINE__
        def #{operation_name}
          @#{operation_name} ||= relation.#{operation_name}.collect { |o| o.bind(self) }
        end
      OPERATION
    end

    private
    def arguments_from_block(relation, &block)
      block_given?? [yield(relation)] : []
    end
  end
end
