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
