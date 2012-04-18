require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/hash/except'
require 'active_support/core_ext/hash/slice'
require 'active_record/relation/merger'

module ActiveRecord
  module SpawnMethods
    def merge(other)
      if other.is_a?(Array)
        to_a & other
      elsif other
        clone.merge!(other)
      else
        self
      end
    end

    def merge!(other)
      if other.is_a?(Hash)
        Relation::HashMerger.new(self, other).merge
      else
        Relation::Merger.new(self, other).merge
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
      result = self.class.new(@klass, table, values.except(*skips))
      result.default_scoped = default_scoped
      result.extend(*extending_values) if extending_values.any?
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
      result = self.class.new(@klass, table, values.slice(*onlies))
      result.default_scoped = default_scoped
      result.extend(*extending_values) if extending_values.any?
      result
    end

  end
end
