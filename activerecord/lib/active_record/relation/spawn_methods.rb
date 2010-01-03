module ActiveRecord
  module SpawnMethods
    def spawn(relation = @relation)
      relation = Relation.new(@klass, relation)
      relation.readonly = @readonly
      relation.preload_associations = @preload_associations
      relation.eager_load_associations = @eager_load_associations
      relation.includes_associations = @includes_associations
      relation.table = table
      relation
    end

    def merge(r)
      raise ArgumentError, "Cannot merge a #{r.klass.name} relation with #{@klass.name} relation" if r.klass != @klass

      merged_relation = spawn(table).eager_load(r.eager_load_associations).preload(r.preload_associations).includes(r.includes_associations)
      merged_relation.readonly = r.readonly

      [self.relation, r.relation].each do |arel|
        merged_relation = merged_relation.
          joins(arel.joins(arel)).
          group(arel.groupings).
          limit(arel.taken).
          offset(arel.skipped).
          select(arel.send(:select_clauses)).
          from(arel.sources).
          having(arel.havings).
          lock(arel.locked)
      end

      relation_order = r.send(:order_clause)
      merged_order = relation_order.present? ? relation_order : order_clause
      merged_relation = merged_relation.order(merged_order)

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

    def except(*skips)
      result = Relation.new(@klass, table)
      result.table = table

      [:eager_load, :preload, :includes].each do |load_method|
        result = result.send(load_method, send(:"#{load_method}_associations"))
      end

      result.readonly = self.readonly unless skips.include?(:readonly)

      result = result.joins(@relation.joins(@relation)) unless skips.include?(:joins)
      result = result.group(@relation.groupings) unless skips.include?(:group)
      result = result.limit(@relation.taken) unless skips.include?(:limit)
      result = result.offset(@relation.skipped) unless skips.include?(:offset)
      result = result.select(@relation.send(:select_clauses)) unless skips.include?(:select)
      result = result.from(@relation.sources) unless skips.include?(:from)
      result = result.order(order_clause) unless skips.include?(:order)
      result = result.where(*@relation.wheres) unless skips.include?(:where)
      result = result.having(*@relation.havings) unless skips.include?(:having)
      result = result.lock(@relation.locked) unless skips.include?(:lock)

      result
    end

  end
end
