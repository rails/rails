module ActiveRecord
  module SpawnMethods
    def merge(r)
      merged_relation = clone
      return merged_relation unless r

      merged_relation = merged_relation.eager_load(r.eager_load_values).preload(r.preload_values).includes(r.includes_values)

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

      merged_relation.order_values = r.order_values if r.order_values.present?

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
      result = self.class.new(@klass, table)

      (Relation::ASSOCIATION_METHODS + Relation::MULTI_VALUE_METHODS).each do |method|
        result.send(:"#{method}_values=", send(:"#{method}_values")) unless skips.include?(method)
      end

      Relation::SINGLE_VALUE_METHODS.each do |method|
        result.send(:"#{method}_value=", send(:"#{method}_value")) unless skips.include?(method)
      end

      result
    end

    def only(*onlies)
      result = self.class.new(@klass, table)

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
      relation = clone
      return relation unless options

      options.assert_valid_keys(VALID_FIND_OPTIONS)

      [:joins, :select, :group, :having, :order, :limit, :offset, :from, :lock, :readonly].each do |finder|
        relation = relation.send(finder, options[finder]) if options.has_key?(finder)
      end

      relation = relation.where(options[:conditions]) if options.has_key?(:conditions)
      relation = relation.includes(options[:include]) if options.has_key?(:include)

      relation
    end

  end
end
