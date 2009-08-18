module ActiveRecord
  class Relation
    delegate :to_sql, :to => :relation
    attr_reader :relation, :klass

    def initialize(klass, relation)
      @klass, @relation = klass, relation
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

    def select(selects)
      Relation.new(@klass, @relation.project(selects))
    end

    def group(groups)
      Relation.new(@klass, @relation.group(groups))
    end

    def order(orders)
      Relation.new(@klass, @relation.order(orders))
    end

    def limit(limits)
      Relation.new(@klass, @relation.take(limits))
    end

    def offset(offsets)
      Relation.new(@klass, @relation.skip(offsets))
    end

    def on(join)
      Relation.new(@klass, @relation.on(join))
    end

    def joins(join, join_type = nil)
      if join.blank?
        self
      else
        join = case join
          when String
            @relation.join(join)
          when Hash, Array, Symbol
            if @klass.send(:array_of_strings?, join)
              @relation.join(join.join(' '))
            else
              @relation.join(@klass.send(:build_association_joins, join))
            end
          else
            @relation.join(join, join_type)
        end
        Relation.new(@klass, join)
      end
    end

    def conditions(conditions)
      if conditions.blank?
        self
      else
        conditions = @klass.send(:merge_conditions, conditions) if [String, Hash, Array].include?(conditions.class)
        Relation.new(@klass, @relation.where(conditions))
      end
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
