module ActiveRecord
  # = Active Record Counter Cache
  module CounterCache
    extend ActiveSupport::Concern

    module ClassMethods
      # Resets one or more counter caches to their correct value using an SQL
      # count query. This is useful when adding new counter caches, or if the
      # counter has been corrupted or modified directly by SQL.
      #
      # ==== Parameters
      #
      # * +id+ - The id of the object you wish to reset a counter on.
      # * +counters+ - One or more counter names to reset
      #
      # ==== Examples
      #
      #   # For Post with id #1 records reset the comments_count
      #   Post.reset_counters(1, :comments)
      def reset_counters(id, *counters)
        object = find(id)
        counters.each do |association|
          has_many_association = reflect_on_association(association.to_sym)

          if has_many_association.is_a? ActiveRecord::Reflection::ThroughReflection
            has_many_association = has_many_association.through_reflection
          end

          foreign_key  = has_many_association.foreign_key.to_s
          child_class  = has_many_association.klass
          belongs_to   = child_class.reflect_on_all_associations(:belongs_to)
          reflection   = belongs_to.find { |e| e.foreign_key.to_s == foreign_key && e.options[:counter_cache].present? }
          counter_name = reflection.counter_cache_column

          stmt = unscoped.where(arel_table[primary_key].eq(object.id)).arel.compile_update({
            arel_table[counter_name] => object.send(association).count
          })
          connection.update stmt
        end
        return true
      end

      # A generic "counter updater" implementation, intended primarily to be
      # used by increment_counter and decrement_counter, but which may also
      # be useful on its own. It simply does a direct SQL update for the record
      # with the given ID, altering the given hash of counters by the amount
      # given by the corresponding value:
      #
      # ==== Parameters
      #
      # * +id+ - The id of the object you wish to update a counter on or an Array of ids.
      # * +counters+ - An Array of Hashes containing the names of the fields
      #   to update as keys and the amount to update the field by as values.
      #
      # ==== Examples
      #
      #   # For the Post with id of 5, decrement the comment_count by 1, and
      #   # increment the action_count by 1
      #   Post.update_counters 5, comment_count: -1, action_count: 1
      #   # Executes the following SQL:
      #   # UPDATE posts
      #   #    SET comment_count = COALESCE(comment_count, 0) - 1,
      #   #        action_count = COALESCE(action_count, 0) + 1
      #   #  WHERE id = 5
      #
      #   # For the Posts with id of 10 and 15, increment the comment_count by 1
      #   Post.update_counters [10, 15], comment_count: 1
      #   # Executes the following SQL:
      #   # UPDATE posts
      #   #    SET comment_count = COALESCE(comment_count, 0) + 1
      #   #  WHERE id IN (10, 15)
      def update_counters(id, counters)
        updates = counters.map do |counter_name, value|
          operator = value < 0 ? '-' : '+'
          quoted_column = connection.quote_column_name(counter_name)
          "#{quoted_column} = COALESCE(#{quoted_column}, 0) #{operator} #{value.abs}"
        end

        where(primary_key => id).update_all updates.join(', ')
      end

      # Increment a number field by one, usually representing a count.
      #
      # This is used for caching aggregate values, so that they don't need to be computed every time.
      # For example, a DiscussionBoard may cache post_count and comment_count otherwise every time the board is
      # shown it would have to run an SQL query to find how many posts and comments there are.
      #
      # ==== Parameters
      #
      # * +counter_name+ - The name of the field that should be incremented.
      # * +id+ - The id of the object that should be incremented.
      #
      # ==== Examples
      #
      #   # Increment the post_count column for the record with an id of 5
      #   DiscussionBoard.increment_counter(:post_count, 5)
      def increment_counter(counter_name, id)
        update_counters(id, counter_name => 1)
      end

      # Decrement a number field by one, usually representing a count.
      #
      # This works the same as increment_counter but reduces the column value by 1 instead of increasing it.
      #
      # ==== Parameters
      #
      # * +counter_name+ - The name of the field that should be decremented.
      # * +id+ - The id of the object that should be decremented.
      #
      # ==== Examples
      #
      #   # Decrement the post_count column for the record with an id of 5
      #   DiscussionBoard.decrement_counter(:post_count, 5)
      def decrement_counter(counter_name, id)
        update_counters(id, counter_name => -1)
      end
    end
  end
end
