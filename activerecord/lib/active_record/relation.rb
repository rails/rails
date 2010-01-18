module ActiveRecord
  class Relation
    JoinOperation = Struct.new(:relation, :join_class, :on)
    ASSOCIATION_METHODS = [:includes, :eager_load, :preload]
    MULTI_VALUE_METHODS = [:select, :group, :order, :joins, :where, :having]
    SINGLE_VALUE_METHODS = [:limit, :offset, :lock, :readonly, :create_with, :from]

    include FinderMethods, CalculationMethods, SpawnMethods, QueryMethods

    delegate :length, :collect, :map, :each, :all?, :include?, :to => :to_a

    attr_reader :table, :klass

    def initialize(klass, table)
      @klass, @table = klass, table
      (ASSOCIATION_METHODS + MULTI_VALUE_METHODS).each {|v| instance_variable_set(:"@#{v}_values", [])}
    end

    def new(*args, &block)
      with_create_scope { @klass.new(*args, &block) }
    end

    alias build new

    def create(*args, &block)
      with_create_scope { @klass.create(*args, &block) }
    end

    def create!(*args, &block)
      with_create_scope { @klass.create!(*args, &block) }
    end

    def respond_to?(method, include_private = false)
      return true if arel.respond_to?(method, include_private) || Array.method_defined?(method)

      if match = DynamicFinderMatch.match(method)
        return true if @klass.send(:all_attributes_exists?, match.attribute_names)
      elsif match = DynamicScopeMatch.match(method)
        return true if @klass.send(:all_attributes_exists?, match.attribute_names)
      else
        super
      end
    end

    def to_a
      return @records if loaded?

      eager_loading = @eager_load_values.any? || (@includes_values.any? && references_eager_loaded_tables?)

      @records = eager_loading ? find_with_associations : @klass.find_by_sql(arel.to_sql)

      preload = @preload_values
      preload +=  @includes_values unless eager_loading
      preload.each {|associations| @klass.send(:preload_associations, @records, associations) } 

      # @readonly_value is true only if set explicity. @implicit_readonly is true if there are JOINS and no explicit SELECT.
      readonly = @readonly_value.nil? ? @implicit_readonly : @readonly_value
      @records.each { |record| record.readonly! } if readonly

      @loaded = true
      @records
    end

    alias all to_a

    def size
      loaded? ? @records.length : count
    end

    def empty?
      loaded? ? @records.empty? : count.zero?
    end

    def any?
      if block_given?
        to_a.any? { |*block_args| yield(*block_args) }
      else
        !empty?
      end
    end

    def many?
      if block_given?
        to_a.many? { |*block_args| yield(*block_args) }
      else
        arel.send(:taken).present? ? to_a.many? : size > 1
      end
    end

    def destroy_all
      to_a.each {|object| object.destroy}
      reset
    end

    def delete_all
      arel.delete.tap { reset }
    end

    def delete(id_or_array)
      where(@klass.primary_key => id_or_array).delete_all
    end

    def loaded?
      @loaded
    end

    def reload
      reset
      to_a # force reload
      self
    end

    def reset
      @first = @last = @to_sql = @order_clause = @scope_for_create = @arel = @loaded = nil
      @records = []
      self
    end

    def primary_key
      @primary_key ||= table[@klass.primary_key]
    end

    def to_sql
      @to_sql ||= arel.to_sql
    end

    def scope_for_create
      @scope_for_create ||= begin
        @create_with_value || wheres.inject({}) do |hash, where|
          hash[where.operand1.name] = where.operand2.value if where.is_a?(Arel::Predicates::Equality)
          hash
        end
      end
    end

    protected

    def method_missing(method, *args, &block)
      if arel.respond_to?(method)
        arel.send(method, *args, &block)
      elsif Array.method_defined?(method)
        to_a.send(method, *args, &block)
      elsif match = DynamicFinderMatch.match(method)
        attributes = match.attribute_names
        super unless @klass.send(:all_attributes_exists?, attributes)

        if match.finder?
          find_by_attributes(match, attributes, *args)
        elsif match.instantiator?
          find_or_instantiator_by_attributes(match, attributes, *args, &block)
        end
      else
        super
      end
    end

    private

    def with_create_scope
      @klass.send(:with_scope, :create => scope_for_create, :find => {}) { yield }
    end

    def where_clause(join_string = " AND ")
      arel.send(:where_clauses).join(join_string)
    end

    def references_eager_loaded_tables?
      joined_tables = (tables_in_string(arel.joins(arel)) + [table.name, table.table_alias]).compact.uniq
      (tables_in_string(to_sql) - joined_tables).any?
    end

    def tables_in_string(string)
      return [] if string.blank?
      string.scan(/([a-zA-Z_][\.\w]+).?\./).flatten.uniq
    end

  end
end
