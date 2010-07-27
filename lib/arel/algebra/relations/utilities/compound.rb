module Arel
  class Compound
    include Relation

    attr_reader :relation
    delegate :joins, :join?, :inserts, :taken, :skipped, :name, :externalizable?,
             :column_for, :sources, :locked, :table_alias, :array,
             :to => :relation

    def initialize relation
      @relation = relation
      @attributes = nil
    end

    [:wheres, :groupings, :orders, :havings, :projections].each do |operation_name|
      class_eval <<-OPERATION, __FILE__, __LINE__
        def #{operation_name}
          @#{operation_name} ||= relation.#{operation_name}.collect { |o| o.bind(self) }
        end
      OPERATION
    end

    def attributes
      @attributes ||= relation.attributes.bind(self)
    end

    def unoperated_rows
      relation.call.collect { |row| row.bind(self) }
    end

    # FIXME: remove this.  :'(
    def hash
      @hash ||= :relation.hash
    end

    def eql?(other)
      self == other
    end

    def engine
      relation.engine
    end

  private

    def arguments_from_block(relation)
      block_given?? [yield(relation)] : []
    end
  end
end
