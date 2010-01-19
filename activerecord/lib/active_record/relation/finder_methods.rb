module ActiveRecord
  module FinderMethods

    def find(*ids, &block)
      return to_a.find(&block) if block_given?

      expects_array = ids.first.kind_of?(Array)
      return ids.first if expects_array && ids.first.empty?

      ids = ids.flatten.compact.uniq

      case ids.size
      when 0
        raise RecordNotFound, "Couldn't find #{@klass.name} without an ID"
      when 1
        result = find_one(ids.first)
        expects_array ? [ result ] : result
      else
        find_some(ids)
      end
    end

    def exists?(id = nil)
      relation = select(primary_key).limit(1)
      relation = relation.where(primary_key.eq(id)) if id
      relation.first ? true : false
    end

    def first
      if loaded?
        @records.first
      else
        @first ||= limit(1).to_a[0]
      end
    end

    def last
      if loaded?
        @records.last
      else
        @last ||= reverse_order.limit(1).to_a[0]
      end
    end

    protected

    def find_with_associations
      including = (@eager_load_values + @includes_values).uniq
      join_dependency = ActiveRecord::Associations::ClassMethods::JoinDependency.new(@klass, including, nil)
      rows = construct_relation_for_association_find(join_dependency).to_a
      join_dependency.instantiate(rows)
    rescue ThrowResult
      []
    end

    def construct_relation_for_association_find(join_dependency)
      relation = except(:includes, :eager_load, :preload, :select).select(@klass.send(:column_aliases, join_dependency))

      for association in join_dependency.join_associations
        relation = association.join_relation(relation)
      end

      limitable_reflections = @klass.send(:using_limitable_reflections?, join_dependency.reflections)

      if !limitable_reflections && relation.limit_value
        limited_id_condition = construct_limited_ids_condition(relation.except(:select))
        relation = relation.where(limited_id_condition)
      end

      relation = relation.except(:limit, :offset) unless limitable_reflections

      relation
    end

    def construct_limited_ids_condition(relation)
      orders = relation.order_values.join(", ")
      values = @klass.connection.distinct("#{@klass.connection.quote_table_name @klass.table_name}.#{@klass.primary_key}", orders)

      ids_array = relation.select(values).collect {|row| row[@klass.primary_key]}
      ids_array.empty? ? raise(ThrowResult) : primary_key.in(ids_array)
    end

    def find_by_attributes(match, attributes, *args)
      conditions = attributes.inject({}) {|h, a| h[a] = args[attributes.index(a)]; h}
      result = where(conditions).send(match.finder)

      if match.bang? && result.blank?
        raise RecordNotFound, "Couldn't find #{@klass.name} with #{conditions.to_a.collect {|p| p.join(' = ')}.join(', ')}"
      else
        result
      end
    end

    def find_or_instantiator_by_attributes(match, attributes, *args)
      guard_protected_attributes = false

      if args[0].is_a?(Hash)
        guard_protected_attributes = true
        attributes_for_create = args[0].with_indifferent_access
        conditions = attributes_for_create.slice(*attributes).symbolize_keys
      else
        attributes_for_create = conditions = attributes.inject({}) {|h, a| h[a] = args[attributes.index(a)]; h}
      end

      record = where(conditions).first

      unless record
        record = @klass.new { |r| r.send(:attributes=, attributes_for_create, guard_protected_attributes) }
        yield(record) if block_given?
        record.save if match.instantiator == :create
      end

      record
    end

    def find_one(id)
      record = where(primary_key.eq(id)).first

      unless record
        conditions = where_clause(', ')
        conditions = " [WHERE #{conditions}]" if conditions.present?
        raise RecordNotFound, "Couldn't find #{@klass.name} with ID=#{id}#{conditions}"
      end

      record
    end

    def find_some(ids)
      result = where(primary_key.in(ids)).all

      expected_size =
        if arel.taken && ids.size > arel.taken
          arel.taken
        else
          ids.size
        end

      # 11 ids with limit 3, offset 9 should give 2 results.
      if arel.skipped && (ids.size - arel.skipped < expected_size)
        expected_size = ids.size - arel.skipped
      end

      if result.size == expected_size
        result
      else
        conditions = where_clause(', ')
        conditions = " [WHERE #{conditions}]" if conditions.present?

        error = "Couldn't find all #{@klass.name.pluralize} with IDs "
        error << "(#{ids.join(", ")})#{conditions} (found #{result.size} results, but was looking for #{expected_size})"
        raise RecordNotFound, error
      end
    end

  end
end
