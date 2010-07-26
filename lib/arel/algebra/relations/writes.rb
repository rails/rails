module Arel
  class Action < Compound
    def == other
      super || self.class === other && @relation == other.relation
    end
  end

  class Deletion < Action
    def call
      engine.delete(self)
    end

    def to_sql
      compiler.delete_sql
    end
  end

  class Insert < Action
    attr_reader :record

    def initialize(relation, record)
      super(relation)
      @record = record.bind(relation)
    end

    def call
      engine.create(self)
    end

    def == other
      super && @record == other.record
    end

    def eval
      unoperated_rows + [Row.new(self, record.values.collect(&:value))]
    end

    def to_sql(include_returning = true)
      compiler.insert_sql(include_returning)
    end
  end

  class Update < Insert
    alias :assignments :record

    def call
      engine.update(self)
    end

    def to_sql
      compiler.update_sql
    end
  end
end
