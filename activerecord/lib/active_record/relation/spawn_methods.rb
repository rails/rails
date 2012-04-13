require 'active_support/core_ext/object/blank'
require 'active_record/relation/merger'

module ActiveRecord
  module SpawnMethods
    def merge(other)
      if other
        case other
        when Array
          to_a & other
        when Hash
          Relation::HashMerger.new(clone, other).merge
        else
          Relation::Merger.new(clone, other).merge
        end
      else
        self
      end
    end

    # Removes from the query the condition(s) specified in +skips+.
    #
    # Example:
    #
    #   Post.order('id asc').except(:order)                  # discards the order condition
    #   Post.where('id > 10').order('id asc').except(:where) # discards the where condition but keeps the order
    #
    def except(*skips)
      result = self.class.new(@klass, table)
      result.default_scoped = default_scoped

      (Relation::MULTI_VALUE_METHODS - skips).each do |method|
        result.send(:"#{method}_values=", send(:"#{method}_values"))
      end

      (Relation::SINGLE_VALUE_METHODS - skips).each do |method|
        result.send(:"#{method}_value=", send(:"#{method}_value"))
      end

      # Apply scope extension modules
      result.send(:apply_modules, extensions)

      result
    end

    # Removes any condition from the query other than the one(s) specified in +onlies+.
    #
    # Example:
    #
    #   Post.order('id asc').only(:where)         # discards the order condition
    #   Post.order('id asc').only(:where, :order) # uses the specified order
    #
    def only(*onlies)
      result = self.class.new(@klass, table)
      result.default_scoped = default_scoped

      (Relation::MULTI_VALUE_METHODS & onlies).each do |method|
        result.send(:"#{method}_values=", send(:"#{method}_values"))
      end

      (Relation::SINGLE_VALUE_METHODS & onlies).each do |method|
        result.send(:"#{method}_value=", send(:"#{method}_value"))
      end

      # Apply scope extension modules
      result.send(:apply_modules, extensions)

      result
    end

  end
end
