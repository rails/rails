module ActiveRecord
  class Relation
    delegate :to_sql, :to => :relation
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

    def select!(selection)
      @relation = @relation.project(selection) if selection
      self
    end

    def on!(on)
      @relation = @relation.on(on) if on
      self
    end

    def order!(order)
      @relation = @relation.order(order) if order
      self
    end

    def group!(group)
      @relation = @relation.group(group) if group
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

    def joins!(joins, join_type = nil)
      if !joins.blank?
        @relation = case joins
        when String
          @relation.join(joins)
        when Hash, Array, Symbol
          if @klass.send(:array_of_strings?, joins)
            @relation.join(joins.join(' '))
          else
            @relation.join(@klass.send(:build_association_joins, joins))
          end
        else
          @relation.join(joins, join_type)
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
