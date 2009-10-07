module ActiveRecord
  class Relation
    delegate :to_sql, :to => :relation
    delegate :length, :collect, :find, :map, :each, :to => :to_a
    attr_reader :relation, :klass

    def initialize(klass, relation)
      @klass, @relation = klass, relation
      @readonly = false
      @associations_to_preload = []
      @eager_load_associations = []
    end

    def preload(association)
      @associations_to_preload += association
      self
    end

    def eager_load(association)
      @eager_load_associations += association
      self
    end

    def readonly
      @readonly = true
      self
    end

    def to_a
      records = if @eager_load_associations.any?
        catch :invalid_query do
          return @klass.send(:find_with_associations, {
            :select => @relation.send(:select_clauses).join(', '),
            :joins => @relation.joins(relation),
            :group => @relation.send(:group_clauses).join(', '),
            :order => @relation.send(:order_clauses).join(', '),
            :conditions => @relation.send(:where_clauses).join("\n\tAND "),
            :limit => @relation.taken,
            :offset => @relation.skipped
            },
            ActiveRecord::Associations::ClassMethods::JoinDependency.new(@klass, @eager_load_associations, nil))
        end
        []
      else
        @klass.find_by_sql(@relation.to_sql)
      end

      @klass.send(:preload_associations, records, @associations_to_preload) unless @associations_to_preload.empty?
      records.each { |record| record.readonly! } if @readonly

      records
    end

    def first
      @relation = @relation.take(1)
      to_a.first
    end

    def select(selects)
      selects.blank? ? self : Relation.new(@klass, @relation.project(selects))
    end

    def group(groups)
      groups.blank? ? self : Relation.new(@klass, @relation.group(groups))
    end

    def order(orders)
      orders.blank? ? self : Relation.new(@klass, @relation.order(orders))
    end

    def limit(limits)
      limits.blank? ? self : Relation.new(@klass, @relation.take(limits))
    end

    def offset(offsets)
      offsets.blank? ? self : Relation.new(@klass, @relation.skip(offsets))
    end

    def on(join)
      join.blank? ? self : Relation.new(@klass, @relation.on(join))
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

    def respond_to?(method)
      if @relation.respond_to?(method) || Array.instance_methods.include?(method.to_s)
        true
      else
        super
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
