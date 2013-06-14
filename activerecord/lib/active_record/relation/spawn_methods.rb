require 'active_support/core_ext/hash/except'
require 'active_support/core_ext/hash/slice'
require 'active_record/relation/merger'

module ActiveRecord
  module SpawnMethods

    # This is overridden by Associations::CollectionProxy
    def spawn #:nodoc:
      clone
    end

    # Merges in the conditions from <tt>other</tt>, if <tt>other</tt> is an <tt>ActiveRecord::Relation</tt>.
    # Returns an array representing the intersection of the resulting records with <tt>other</tt>, if <tt>other</tt> is an array.
    #   Post.where(published: true).joins(:comments).merge( Comment.where(spam: false) )
    #   # Performs a single join query with both where conditions.
    #
    #   recent_posts = Post.order('created_at DESC').first(5)
    #   Post.where(published: true).merge(recent_posts)
    #   # Returns the intersection of all published posts with the 5 most recently created posts.
    #   # (This is just an example. You'd probably want to do this with a single query!)
    #
    # Procs will be evaluated by merge:
    #
    #   Post.where(published: true).merge(-> { joins(:comments) })
    #   # => Post.where(published: true).joins(:comments)
    #
    # This is mainly intended for sharing common conditions between multiple associations.
    def merge(other)
      if other.is_a?(Array)
        to_a & other
      elsif other
        spawn.merge!(other)
      else
        self
      end
    end

    def merge!(other) # :nodoc:
      if !other.is_a?(Relation) && other.respond_to?(:to_proc)
        instance_exec(&other)
      else
        klass = other.is_a?(Hash) ? Relation::HashMerger : Relation::Merger
        klass.new(self, other).merge
      end
    end

    # Removes from the query the condition(s) specified in +skips+.
    #
    #   Post.order('id asc').except(:order)                  # discards the order condition
    #   Post.where('id > 10').order('id asc').except(:where) # discards the where condition but keeps the order
    def except(*skips)
      values_except_skips    = values.except(*skips)
      relation               = relation_with(values_except_skips)
      skips_in_default_scope = shared_values_in_default_scope(skips)

      if skips_in_default_scope.any?
        relation.unscope(skips_in_default_scope)
      else
        relation
      end
    end

    # Removes any condition from the query other than the one(s) specified in +onlies+.
    #
    #   Post.order('id asc').only(:where)         # discards the order condition
    #   Post.order('id asc').only(:where, :order) # uses the specified order
    def only(*onlies)
      relation_with values.slice(*onlies)
    end

    private

      def relation_with(values) # :nodoc:
        result = Relation.new(klass, table, values)
        result.default_scoped = default_scoped
        result.extend(*extending_values) if extending_values.any?
        result
      end

      def shared_values_in_default_scope(values)
        values.select { |value| in_default_scope?(value) }
      end

      def in_default_scope?(value)
        default_scope_values.has_key?(value)
      end
  end
end
