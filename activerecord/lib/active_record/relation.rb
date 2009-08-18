module ActiveRecord
  class Relation
    delegate :delete, :to_sql, :to => :relation
    CLAUSES_METHODS = ["project", "where", "group", "order", "take", "skip", "on"].freeze
    attr_reader :relation, :klass

    def initialize(klass, table = nil)
      @klass = klass
      @relation = Arel::Table.new(table || @klass.table_name)
    end

    def to_a
      @klass.find_by_sql(@relation.to_sql)
    end

    def each(&block)
      to_a.each(&block)
    end

    def first
      @relation = @relation.take(1)
      to_a.first
    end

    for clause in CLAUSES_METHODS
      class_eval %{
        def #{clause}!(_#{clause})
          @relation = @relation.#{clause}(_#{clause}) if _#{clause}
          self
        end
      }
    end


    def select!(selection)
      @relation = @relation.project(selection) if selection
      self
    end

    def limit!(limit)
      @relation = @relation.take(limit) if limit
      self
    end

    def offset!(offset)
      @relation = @relation.skip(offset) if offset
      self
    end

    def joins!(join, join_type = nil)
      if !join.blank?
        if [String, Hash, Array, Symbol].include?(join.class)
          @relation = @relation.join(@klass.send(:construct_join, join, nil))
        else
          @relation = @relation.join(join, join_type)
        end
      end
      self
    end

    def conditions!(conditions)
      if !conditions.blank?
        conditions = @klass.send(:merge_conditions, conditions) if [String, Hash, Array].include?(conditions.class)
        @relation = @relation.where(conditions)
      end
      self
    end

    private
      def method_missing(method, *args, &block)
        if @relation.respond_to?(method)
          @relation.send(method, *args, &block)
        elsif Array.instance_methods.include?(method.to_s)
          to_a.send(method, *args, &block)
        end
      end
  end
end
