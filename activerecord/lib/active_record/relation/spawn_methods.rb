require 'active_support/core_ext/object/blank'

module ActiveRecord
  module SpawnMethods
    def merge(r)
      merged_relation = clone
      return merged_relation unless r

      ((Relation::ASSOCIATION_METHODS + Relation::MULTI_VALUE_METHODS) - [:joins, :where]).each do |method|
        value = r.send(:"#{method}_values")
        merged_relation.send(:"#{method}_values=", value) if value.present?
      end

      merged_relation = merged_relation.joins(r.joins_values)

      merged_wheres = @where_values

      r.where_values.each do |w|
        if w.is_a?(Arel::Predicates::Equality)
          merged_wheres = merged_wheres.reject {|p| p.is_a?(Arel::Predicates::Equality) && p.operand1.name == w.operand1.name }
        end

        merged_wheres += [w]
      end

      merged_relation.where_values = merged_wheres

      Relation::SINGLE_VALUE_METHODS.reject {|m| m == :lock}.each do |method|
        unless (value = r.send(:"#{method}_value")).nil?
          merged_relation.send(:"#{method}_value=", value)
        end
      end

      merged_relation.lock_value = r.lock_value unless merged_relation.lock_value

      # Apply scope extension modules
      merged_relation.send :apply_modules, r.extensions

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

    VALID_FIND_OPTIONS = [ :conditions, :include, :joins, :limit, :offset, :extend,
                           :order, :select, :readonly, :group, :having, :from, :lock ]

    def apply_finder_options(options)
      relation = clone
      return relation unless options

      options.assert_valid_keys(VALID_FIND_OPTIONS)

      [:joins, :select, :group, :having, :limit, :offset, :from, :lock, :readonly].each do |finder|
        relation = relation.send(finder, options[finder]) if options.has_key?(finder)
      end

      # Give precedence to newly-applied orders and groups to play nicely with with_scope
      [:group, :order].each do |finder|
        relation.send("#{finder}_values=", Array.wrap(options[finder]) + relation.send("#{finder}_values")) if options.has_key?(finder)
      end

      relation = relation.where(options[:conditions]) if options.has_key?(:conditions)
      relation = relation.includes(options[:include]) if options.has_key?(:include)
      relation = relation.extending(options[:extend]) if options.has_key?(:extend)

      relation
    end

  end
end
