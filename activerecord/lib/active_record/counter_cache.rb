# frozen_string_literal: true

module ActiveRecord
  # = Active Record Counter Cache
  module CounterCache
    extend ActiveSupport::Concern

    included do
      class_attribute :_counter_cache_columns, instance_accessor: false, default: []
      class_attribute :counter_cached_association_names, instance_writer: false, default: []
    end

    module ClassMethods
      # Resets one or more counter caches to their correct value using an SQL
      # count query. This is useful when adding new counter caches, or if the
      # counter has been corrupted or modified directly by SQL.
      #
      # ==== Parameters
      #
      # * +id+ - The id of the object you wish to reset a counter on.
      # * +counters+ - One or more association counters to reset. Association name or counter name can be given.
      # * <tt>:touch</tt> - Touch timestamp columns when updating.
      #   Pass +true+ to touch +updated_at+ and/or +updated_on+. Pass a symbol to
      #   touch that column or an array of symbols to touch just those ones.
      #
      # ==== Examples
      #
      #   # For the Post with id #1, reset the comments_count
      #   Post.reset_counters(1, :comments)
      #
      #   # Like above, but also touch the +updated_at+ and/or +updated_on+
      #   # attributes.
      #   Post.reset_counters(1, :comments, touch: true)
      def reset_counters(id, *counters, touch: nil)
        object = find(id)

        updates = {}
        counters.each do |counter_association|
          has_many_association = _reflect_on_association(counter_association)
          unless has_many_association
            has_many = reflect_on_all_associations(:has_many)
            has_many_association = has_many.find { |association| association.counter_cache_column && association.counter_cache_column.to_sym == counter_association.to_sym }
            counter_association = has_many_association.plural_name if has_many_association
          end
          raise ArgumentError, "'#{name}' has no association called '#{counter_association}'" unless has_many_association

          if has_many_association.is_a? ActiveRecord::Reflection::ThroughReflection
            has_many_association = has_many_association.through_reflection
          end

          foreign_key  = has_many_association.foreign_key.to_s
          child_class  = has_many_association.klass
          reflection   = child_class._reflections.values.find { |e| e.belongs_to? && e.foreign_key.to_s == foreign_key && e.options[:counter_cache].present? }
          counter_name = reflection.counter_cache_column

          count_was = object.send(counter_name)
          count = object.send(counter_association).count(:all)
          updates[counter_name] = count if count != count_was
        end

        if touch
          names = touch if touch != true
          names = Array.wrap(names)
          options = names.extract_options!
          touch_updates = touch_attributes_with_time(*names, **options)
          updates.merge!(touch_updates)
        end

        unscoped.where(primary_key => [object.id]).update_all(updates) if updates.any?

        true
      end

      # A generic "counter updater" implementation, intended primarily to be
      # used by #increment_counter and #decrement_counter, but which may also
      # be useful on its own. It simply does a direct SQL update for the record
      # with the given ID, altering the given hash of counters by the amount
      # given by the corresponding value:
      #
      # ==== Parameters
      #
      # * +id+ - The id of the object you wish to update a counter on or an array of ids.
      # * +counters+ - A Hash containing the names of the fields
      #   to update as keys and the amount to update the field by as values.
      # * <tt>:touch</tt> option - Touch timestamp columns when updating.
      #   If attribute names are passed, they are updated along with updated_at/on
      #   attributes.
      #
      # ==== Examples
      #
      #   # For the Post with id of 5, decrement the comments_count by 1, and
      #   # increment the actions_count by 1
      #   Post.update_counters 5, comments_count: -1, actions_count: 1
      #   # Executes the following SQL:
      #   # UPDATE posts
      #   #    SET comments_count = COALESCE(comments_count, 0) - 1,
      #   #        actions_count = COALESCE(actions_count, 0) + 1
      #   #  WHERE id = 5
      #
      #   # For the Posts with id of 10 and 15, increment the comments_count by 1
      #   Post.update_counters [10, 15], comments_count: 1
      #   # Executes the following SQL:
      #   # UPDATE posts
      #   #    SET comments_count = COALESCE(comments_count, 0) + 1
      #   #  WHERE id IN (10, 15)
      #
      #   # For the Posts with id of 10 and 15, increment the comments_count by 1
      #   # and update the updated_at value for each counter.
      #   Post.update_counters [10, 15], comments_count: 1, touch: true
      #   # Executes the following SQL:
      #   # UPDATE posts
      #   #    SET comments_count = COALESCE(comments_count, 0) + 1,
      #   #    `updated_at` = '2016-10-13T09:59:23-05:00'
      #   #  WHERE id IN (10, 15)
      def update_counters(id, counters)
        id = [id] if composite_primary_key? && id.is_a?(Array) && !id[0].is_a?(Array)
        unscoped.where!(primary_key => id).update_counters(counters)
      end

      # Increment a numeric field by one, via a direct SQL update.
      #
      # This method is used primarily for maintaining counter_cache columns that are
      # used to store aggregate values. For example, a +DiscussionBoard+ may cache
      # posts_count and comments_count to avoid running an SQL query to calculate the
      # number of posts and comments there are, each time it is displayed.
      #
      # ==== Parameters
      #
      # * +counter_name+ - The name of the field that should be incremented.
      # * +id+ - The id of the object that should be incremented or an array of ids.
      # * <tt>:by</tt> - The amount by which to increment the value. Defaults to +1+.
      # * <tt>:touch</tt> - Touch timestamp columns when updating.
      #   Pass +true+ to touch +updated_at+ and/or +updated_on+. Pass a symbol to
      #   touch that column or an array of symbols to touch just those ones.
      #
      # ==== Examples
      #
      #   # Increment the posts_count column for the record with an id of 5
      #   DiscussionBoard.increment_counter(:posts_count, 5)
      #
      #   # Increment the posts_count column for the record with an id of 5
      #   # by a specific amount.
      #   DiscussionBoard.increment_counter(:posts_count, 5, by: 3)
      #
      #   # Increment the posts_count column for the record with an id of 5
      #   # and update the updated_at value.
      #   DiscussionBoard.increment_counter(:posts_count, 5, touch: true)
      def increment_counter(counter_name, id, by: 1, touch: nil)
        update_counters(id, counter_name => by, touch: touch)
      end

      # Decrement a numeric field by one, via a direct SQL update.
      #
      # This works the same as #increment_counter but reduces the column value by
      # 1 instead of increasing it.
      #
      # ==== Parameters
      #
      # * +counter_name+ - The name of the field that should be decremented.
      # * +id+ - The id of the object that should be decremented or an array of ids.
      # * <tt>:by</tt> - The amount by which to decrement the value. Defaults to +1+.
      # * <tt>:touch</tt> - Touch timestamp columns when updating.
      #   Pass +true+ to touch +updated_at+ and/or +updated_on+. Pass a symbol to
      #   touch that column or an array of symbols to touch just those ones.
      #
      # ==== Examples
      #
      #   # Decrement the posts_count column for the record with an id of 5
      #   DiscussionBoard.decrement_counter(:posts_count, 5)
      #
      #   # Decrement the posts_count column for the record with an id of 5
      #   by a specific amount.
      #   DiscussionBoard.decrement_counter(:posts_count, 5, by: 3)
      #
      #   # Decrement the posts_count column for the record with an id of 5
      #   # and update the updated_at value.
      #   DiscussionBoard.decrement_counter(:posts_count, 5, touch: true)
      def decrement_counter(counter_name, id, by: 1, touch: nil)
        update_counters(id, counter_name => -by, touch: touch)
      end

      def counter_cache_column?(name) # :nodoc:
        _counter_cache_columns.include?(name)
      end

      def load_schema! # :nodoc:
        super

        association_names = _reflections.filter_map do |name, reflection|
          next unless reflection.belongs_to? && reflection.counter_cache_column

          name.to_sym
        end

        self.counter_cached_association_names |= association_names
      end
    end

    private
      def _create_record(attribute_names = self.attribute_names)
        id = super

        counter_cached_association_names.each do |association_name|
          association(association_name).increment_counters
        end

        id
      end

      def destroy_row
        affected_rows = super

        if affected_rows > 0
          counter_cached_association_names.each do |association_name|
            association = association(association_name)

            unless destroyed_by_association && _foreign_keys_equal?(destroyed_by_association.foreign_key, association.reflection.foreign_key)
              association.decrement_counters
            end
          end
        end

        affected_rows
      end

      def _foreign_keys_equal?(fkey1, fkey2)
        fkey1 == fkey2 || Array(fkey1).map(&:to_sym) == Array(fkey2).map(&:to_sym)
      end
  end
end
