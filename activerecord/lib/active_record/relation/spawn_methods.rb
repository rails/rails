require 'active_support/core_ext/object/blank'
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
    #
    # ==== Examples
    #
    #   Post.where(:published => true).joins(:comments).merge( Comment.where(:spam => false) )
    #   # Performs a single join query with both where conditions.
    #
    #   recent_posts = Post.order('created_at DESC').first(5)
    #   Post.where(:published => true).merge(recent_posts)
    #   # Returns the intersection of all published posts with the 5 most recently created posts.
    #   # (This is just an example. You'd probably want to do this with a single query!)
    #
    def merge(other)
      if other.is_a?(Array)
        to_a & other
      elsif other
        spawn.merge!(other)
      else
        self
      end
    end

    def merge!(other)
      klass = other.is_a?(Hash) ? Relation::HashMerger : Relation::Merger
      klass.new(self, other).merge
    end

    # Removes from the query the condition(s) specified in +skips+.
    #
    # Example:
    #
    #   Post.order('id asc').except(:order)                  # discards the order condition
    #   Post.where('id > 10').order('id asc').except(:where) # discards the where condition but keeps the order
    #
    def except(*skips)
      result = Relation.new(klass, table, values.except(*skips))
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
      result = Relation.new(klass, table, values.slice(*onlies))
      result.default_scoped = default_scoped
      result.extend(*extending_values) if extending_values.any?
      result
    end

    VALID_FIND_OPTIONS = [ :conditions, :where, :include, :includes, :joins,
                           :limit, :offset, :extend, :extending, :references,
                           :order, :select, :readonly, :group, :having, :from,
                           :lock ]

    def apply_finder_options(options)
      relation = clone
      return relation unless options

      finders = sanitize_finder_options(options.dup)

      finders.keys.inject(relation) do |rel, finder|
        rel.send(finder, finders[finder])
      end
    end

    private

    def sanitize_finder_options(options)
      filter_invalid options
      filter_empty options
      substitute_keys options
    end

    def filter_invalid(options)
      options.assert_valid_keys(VALID_FIND_OPTIONS)
    end

    def filter_empty(options)
      options.delete_if { |key, value| value.nil? && key != :limit }
    end

    # Substitutes keys for which Relation::QueryMethods has no method by ones
    # for which there is a method.
    def substitute_keys(options)
      options.inject({}) do |finders, (key, value)|

        key = :where     if key == :conditions
        key = :includes  if key == :include
        key = :extending if key == :extend

        finders[key] = value
        finders
      end
    end

  end
end
