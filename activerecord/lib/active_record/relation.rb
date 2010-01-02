module ActiveRecord
  class Relation
    include QueryMethods, FinderMethods, CalculationMethods

    delegate :length, :collect, :map, :each, :all?, :to => :to_a

    attr_reader :relation, :klass
    attr_writer :readonly, :table
    attr_accessor :preload_associations, :eager_load_associations, :include_associations

    def initialize(klass, relation)
      @klass, @relation = klass, relation
      @preload_associations = []
      @eager_load_associations = []
      @include_associations = []
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

    def merge(r)
      raise ArgumentError, "Cannot merge a #{r.klass.name} relation with #{@klass.name} relation" if r.klass != @klass

      merged_relation = spawn(table).eager_load(r.eager_load_associations).preload(r.preload_associations).includes(r.include_associations)
      merged_relation.readonly = r.readonly

      [self.relation, r.relation].each do |arel|
        merged_relation = merged_relation.
          joins(arel.joins(arel)).
          group(arel.groupings).
          order(arel.send(:order_clauses).join(', ')).
          limit(arel.taken).
          offset(arel.skipped).
          select(arel.send(:select_clauses)).
          from(arel.sources)
      end

      merged_wheres = @relation.wheres

      r.wheres.each do |w|
        if w.is_a?(Arel::Predicates::Equality)
          merged_wheres = merged_wheres.reject {|p| p.is_a?(Arel::Predicates::Equality) && p.operand1.name == w.operand1.name }
        end

        merged_wheres << w
      end

      merged_relation.where(*merged_wheres)
    end

    alias :& :merge

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
            :order => @relation.send(:order_clauses).join(', '),
            :conditions => where_clause,
            :limit => @relation.taken,
            :offset => @relation.skipped,
            :from => (@relation.send(:from_clauses) if @relation.send(:sources).present?)
            },
            ActiveRecord::Associations::ClassMethods::JoinDependency.new(@klass, @eager_load_associations + @include_associations, nil))
        rescue ThrowResult
          []
        end
      else
        @klass.find_by_sql(@relation.to_sql)
      end

      preload = @preload_associations
      preload +=  @include_associations unless find_with_associations
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
      @first = @last = @create_scope = @joined_tables = @to_sql = nil
      @records = []
      self
    end

    def spawn(relation = @relation)
      relation = Relation.new(@klass, relation)
      relation.readonly = @readonly
      relation.preload_associations = @preload_associations
      relation.eager_load_associations = @eager_load_associations
      relation.include_associations = @include_associations
      relation.table = table
      relation
    end

    def table
      @table ||= Arel::Table.new(@klass.table_name, Arel::Sql::Engine.new(@klass))
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

    def references_eager_loaded_tables?
      include_eager_order? || include_eager_conditions? || include_eager_select?
    end

    def include_eager_order?
      order_clause = @relation.send(:order_clauses).join(', ')
      (tables_in_string(order_clause) - joined_tables).any?
    end

    def include_eager_conditions?
      (tables_in_string(where_clause) - joined_tables).any?
    end

    def include_eager_select?
      select_clause = @relation.send(:select_clauses).join(', ')
      (tables_in_string(select_clause) - joined_tables).any?
    end

    def joined_tables
      @joined_tables ||= (tables_in_string(@relation.joins(relation)) + [table.name, table.table_alias]).compact.uniq
    end

    def tables_in_string(string)
      return [] if string.blank?
      string.scan(/([a-zA-Z_][\.\w]+).?\./).flatten.uniq
    end

  end
end
