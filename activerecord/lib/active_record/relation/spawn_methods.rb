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
          from(arel.sources)
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

  end
end
