module Arel
  class Compound < Relation
    attr_reader :relation
    delegate :joins, :join?, :inserts, :taken, :skipped, :name, :externalizable?,
             :column_for, :engine, :sources, :locked, :table_alias,
             :to => :relation

    [:attributes, :wheres, :groupings, :orders, :havings].each do |operation_name|
      class_eval <<-OPERATION, __FILE__, __LINE__
        def #{operation_name}
          @#{operation_name} ||= relation.#{operation_name}.collect { |o| o.bind(self) }
        end
      OPERATION
    end

    def hash
      @hash ||= :relation.hash
    end

    def eql?(other)
      self == other
    end

  private

    def arguments_from_block(relation, &block)
      block_given?? [yield(relation)] : []
    end
  end
end
