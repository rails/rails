module ActiveRecord
  class Relation
    delegate :to_sql, :to => :relation
    delegate :length, :collect, :find, :map, :each, :to => :to_a
    attr_reader :relation, :klass

    def initialize(klass, relation, readonly = false, preload = [], eager_load = [])
      @klass, @relation = klass, relation
      @readonly = readonly
      @associations_to_preload = preload
      @eager_load_associations = eager_load
    end

    def preload(associations)
      @associations_to_preload << associations
      self
    end

    def eager_load(associations)
      @eager_load_associations += Array.wrap(associations)
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

      @associations_to_preload.each {|associations| @klass.send(:preload_associations, records, associations) }
      records.each { |record| record.readonly! } if @readonly

      records
    end

    def first
      @relation = @relation.take(1)
      to_a.first
    end

    def select(selects)
      selects.blank? ? self : create_new_relation(@relation.project(selects))
    end

    def group(groups)
      groups.blank? ? self : create_new_relation(@relation.group(groups))
    end

    def order(orders)
      orders.blank? ? self : create_new_relation(@relation.order(orders))
    end

    def limit(limits)
      limits.blank? ? self : create_new_relation(@relation.take(limits))
    end

    def offset(offsets)
      offsets.blank? ? self : create_new_relation(@relation.skip(offsets))
    end

    def on(join)
      join.blank? ? self : create_new_relation(@relation.on(join))
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
        create_new_relation(join)
      end
    end

    def where(conditions)
      if conditions.blank?
        self
      else
        conditions = @klass.send(:merge_conditions, conditions) if [String, Hash, Array].include?(conditions.class)
        create_new_relation(@relation.where(conditions))
      end
    end

    def respond_to?(method)
      @relation.respond_to?(method) || Array.method_defined?(method) || super
    end

    private

    def method_missing(method, *args, &block)
      if @relation.respond_to?(method)
        @relation.send(method, *args, &block)
      elsif Array.method_defined?(method)
        to_a.send(method, *args, &block)
      else
        super
      end
    end

    def create_new_relation(relation)
      Relation.new(@klass, relation, @readonly, @associations_to_preload, @eager_load_associations)
    end

  end
end
