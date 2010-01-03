module ActiveRecord
  class Relation
    include QueryMethods, FinderMethods, CalculationMethods, SpawnMethods

    delegate :length, :collect, :map, :each, :all?, :to => :to_a

    attr_reader :relation, :klass
    attr_writer :readonly, :table
    attr_accessor :preload_associations, :eager_load_associations, :includes_associations

    def initialize(klass, relation)
      @klass, @relation = klass, relation
      @preload_associations = []
      @eager_load_associations = []
      @includes_associations = []
      @loaded, @readonly = false
    end

    def new(*args, &block)
      with_create_scope { @klass.new(*args, &block) }
    end

    def create(*args, &block)
      with_create_scope { @klass.create(*args, &block) }
    end

    def create!(*args, &block)
      with_create_scope { @klass.create!(*args, &block) }
    end

    def respond_to?(method, include_private = false)
      return true if @relation.respond_to?(method, include_private) || Array.method_defined?(method)

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

      find_with_associations = @eager_load_associations.any? || references_eager_loaded_tables?

      @records = if find_with_associations
        begin
          @klass.send(:find_with_associations, {
            :select => @relation.send(:select_clauses).join(', '),
            :joins => @relation.joins(relation),
            :group => @relation.send(:group_clauses).join(', '),
            :order => order_clause,
            :conditions => where_clause,
            :limit => @relation.taken,
            :offset => @relation.skipped,
            :from => (@relation.send(:from_clauses) if @relation.send(:sources).present?)
            },
            ActiveRecord::Associations::ClassMethods::JoinDependency.new(@klass, @eager_load_associations + @includes_associations, nil))
        rescue ThrowResult
          []
        end
      else
        @klass.find_by_sql(@relation.to_sql)
      end

      preload = @preload_associations
      preload +=  @includes_associations unless find_with_associations
      preload.each {|associations| @klass.send(:preload_associations, @records, associations) } 

      @records.each { |record| record.readonly! } if @readonly

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
        @relation.send(:taken).present? ? to_a.many? : size > 1
      end
    end

    def destroy_all
      to_a.each {|object| object.destroy}
      reset
    end

    def delete_all
      @relation.delete.tap { reset }
    end

    def delete(id_or_array)
      where(@klass.primary_key => id_or_array).delete_all
    end

    def loaded?
      @loaded
    end

    def reload
      @loaded = false
      reset
    end

    def reset
      @first = @last = @create_scope = @to_sql = @order_clause = nil
      @records = []
      self
    end

    def table
      @table ||= Arel::Table.new(@klass.table_name, :engine => @klass.active_relation_engine)
    end

    def primary_key
      @primary_key ||= table[@klass.primary_key]
    end

    def to_sql
      @to_sql ||= @relation.to_sql
    end

    protected

    def method_missing(method, *args, &block)
      if @relation.respond_to?(method)
        @relation.send(method, *args, &block)
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

    def with_create_scope
      @klass.send(:with_scope, :create => create_scope) { yield }
    end

    def create_scope
      @create_scope ||= wheres.inject({}) do |hash, where|
        hash[where.operand1.name] = where.operand2.value if where.is_a?(Arel::Predicates::Equality)
        hash
      end
    end

    def where_clause(join_string = " AND ")
      @relation.send(:where_clauses).join(join_string)
    end

    def order_clause
      @order_clause ||= @relation.send(:order_clauses).join(', ')
    end

    def references_eager_loaded_tables?
      joined_tables = (tables_in_string(@relation.joins(relation)) + [table.name, table.table_alias]).compact.uniq
      (tables_in_string(to_sql) - joined_tables).any?
    end

    def tables_in_string(string)
      return [] if string.blank?
      string.scan(/([a-zA-Z_][\.\w]+).?\./).flatten.uniq
    end

  end
end
