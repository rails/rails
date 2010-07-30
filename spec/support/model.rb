module Arel
  module Testing
    class Engine < Arel::Memory::Engine
      attr_reader :rows

      def initialize
        @rows = []
      end

      def supports(operation)
        false
      end

      def read(relation)
        case relation
        when Arel::Take, Arel::Order, Arel::Skip, Arel::Where
          relation.eval
        else
          @rows.dup.map { |r| Row.new(relation, r) }
        end
      end

      def create(insert)
        @rows << insert.record.tuple
        insert
      end
    end
  end

  class Model
    include Relation

    attr_reader :engine

    def self.build
      relation = new
      yield relation
      relation
    end

    def initialize
      @attributes = []
    end

    def engine(engine = nil)
      @engine = engine if engine
      @engine
    end

    def attribute(name, type)
      @attributes << type.new(self, name)
    end

    def attributes
      Header.new(@attributes)
    end

    def format(attribute, value)
      value
    end

    def insert(row)
      insert = super Arel::Row.new(self, row)
      insert.record
    end
  end
end
