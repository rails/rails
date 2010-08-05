module Arel
  class Compound
    include Relation

    attr_reader :relation, :engine

    def initialize relation
      @relation    = relation
      @engine      = relation.engine
      @attributes  = nil
      @wheres      = nil
      @groupings   = nil
      @orders      = nil
      @havings     = nil
      @projections = nil
    end

    def join?;           @relation.join?           end
    def name;            @relation.name            end
    def table_alias;     @relation.table_alias     end
    def skipped;         @relation.skipped         end
    def taken;           @relation.taken           end
    def joins env;       @relation.joins env       end
    def column_for attr; @relation.column_for attr end
    def externalizable?; @relation.externalizable? end

    def sources
      @relation.sources
    end

    def table
      @relation.table
    end

    def table_sql(formatter = Sql::TableReference.new(self))
      @relation.table_sql formatter
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
  end
end
