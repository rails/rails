module ActiveRecord
  module SpawnMethods
    def spawn(arel_table = self.table)
      relation = Relation.new(@klass, arel_table)

      (Relation::ASSOCIATION_METHODS + Relation::MULTI_VALUE_METHODS).each do |query_method|
        relation.send(:"#{query_method}_values=", send(:"#{query_method}_values"))
      end

      Relation::SINGLE_VALUE_METHODS.each do |query_method|
        relation.send(:"#{query_method}_value=", send(:"#{query_method}_value"))
      end

      relation
    end

    def merge(r)
      if r.klass != @klass
        raise ArgumentError, "Cannot merge a #{r.klass.name}(##{r.klass.object_id}) relation with #{@klass.name}(##{@klass.object_id}) relation"
      end

      merged_relation = spawn.eager_load(r.eager_load_values).preload(r.preload_values).includes(r.includes_values)

      merged_relation.readonly_value = r.readonly_value unless r.readonly_value.nil?
      merged_relation.limit_value = r.limit_value if r.limit_value.present?
      merged_relation.lock_value = r.lock_value unless merged_relation.lock_value
      merged_relation.offset_value = r.offset_value if r.offset_value.present?

      merged_relation = merged_relation.
        joins(r.joins_values).
        group(r.group_values).
        select(r.select_values).
        from(r.from_value).
        having(r.having_values)

      merged_relation.order_values = Array.wrap(order_values) + Array.wrap(r.order_values)

      merged_relation.create_with_value = @create_with_value

      if @create_with_value && r.create_with_value
        merged_relation.create_with_value = @create_with_value.merge(r.create_with_value)
      else
        merged_relation.create_with_value = r.create_with_value || @create_with_value
      end

      merged_wheres = @where_values

      r.where_values.each do |w|
        if w.is_a?(Arel::Predicates::Equality)
          merged_wheres = merged_wheres.reject {|p| p.is_a?(Arel::Predicates::Equality) && p.operand1.name == w.operand1.name }
        end

        merged_wheres += [w]
      end

      merged_relation.where_values = merged_wheres

      merged_relation
    end

    alias :& :merge

    def except(*skips)
      result = Relation.new(@klass, table)

      (Relation::ASSOCIATION_METHODS + Relation::MULTI_VALUE_METHODS).each do |method|
        result.send(:"#{method}_values=", send(:"#{method}_values")) unless skips.include?(method)
      end

      Relation::SINGLE_VALUE_METHODS.each do |method|
        result.send(:"#{method}_value=", send(:"#{method}_value")) unless skips.include?(method)
      end

      result
    end

    def only(*onlies)
      result = Relation.new(@klass, table)

      onlies.each do |only|
        if (Relation::ASSOCIATION_METHODS + Relation::MULTI_VALUE_METHODS).include?(only)
          result.send(:"#{only}_values=", send(:"#{only}_values"))
        elsif Relation::SINGLE_VALUE_METHODS.include?(only)
          result.send(:"#{only}_value=", send(:"#{only}_value"))
        else
          raise "Invalid argument : #{only}"
        end
      end

      result
    end

    VALID_FIND_OPTIONS = [ :conditions, :include, :joins, :limit, :offset,
                           :order, :select, :readonly, :group, :having, :from, :lock ]

    def apply_finder_options(options)
      options.assert_valid_keys(VALID_FIND_OPTIONS)

      relation = spawn

      relation = relation.joins(options[:joins]).
        where(options[:conditions]).
        select(options[:select]).
        group(options[:group]).
        having(options[:having]).
        order(options[:order]).
        limit(options[:limit]).
        offset(options[:offset]).
        from(options[:from]).
        includes(options[:include])

      relation = relation.lock(options[:lock]) if options[:lock].present?
      relation = relation.readonly(options[:readonly]) if options.has_key?(:readonly)

      relation
    end

  end
end
