# frozen_string_literal: true

require "active_support/core_ext/enumerable"

module ActiveRecord
  module Associations
    # = Active Record Association Collection
    #
    # CollectionAssociation is an abstract class that provides common stuff to
    # ease the implementation of association proxies that represent
    # collections. See the class hierarchy in Association.
    #
    #   CollectionAssociation:
    #     HasManyAssociation => has_many
    #       HasManyThroughAssociation + ThroughAssociation => has_many :through
    #
    # The CollectionAssociation class provides common methods to the collections
    # defined by +has_and_belongs_to_many+, +has_many+ or +has_many+ with
    # the <tt>:through association</tt> option.
    #
    # You need to be careful with assumptions regarding the target: The proxy
    # does not fetch records from the database until it needs them, but new
    # ones created with +build+ are added to the target. So, the target may be
    # non-empty and still lack children waiting to be read from the database.
    # If you look directly to the database you cannot assume that's the entire
    # collection because new records may have been added to the target, etc.
    #
    # If you need to work on all current children, new and existing records,
    # +load_target+ and the +loaded+ flag are your friends.
    class CollectionAssociation < Association # :nodoc:
      attr_accessor :nested_attributes_target

      # Implements the reader method, e.g. foo.items for Foo.has_many :items
      def reader
        ensure_klass_exists!

        if stale_target?
          reload
        end

        @proxy ||= CollectionProxy.create(klass, self)
        @proxy.reset_scope
      end

      # Implements the writer method, e.g. foo.items= for Foo.has_many :items
      def writer(records)
        replace(records)
      end

      # Implements the ids reader method, e.g. foo.item_ids for Foo.has_many :items
      def ids_reader
        if loaded?
          target.pluck(*reflection.association_primary_key)
        elsif !target.empty?
          load_target.pluck(*reflection.association_primary_key)
        else
          @association_ids ||= scope.pluck(*reflection.association_primary_key)
        end
      end

      # Implements the ids writer method, e.g. foo.item_ids= for Foo.has_many :items
      def ids_writer(ids)
        primary_key = reflection.association_primary_key
        pk_type = klass.type_for_attribute(primary_key)
        ids = Array(ids).compact_blank
        ids.map! { |id| pk_type.cast(id) }

        records = if klass.composite_primary_key?
          klass.where(primary_key => ids).index_by do |record|
            primary_key.map { |primary_key| record._read_attribute(primary_key) }
          end
        else
          klass.where(primary_key => ids).index_by do |record|
            record._read_attribute(primary_key)
          end
        end.values_at(*ids).compact

        if records.size != ids.size
          found_ids = records.map { |record| record._read_attribute(primary_key) }
          not_found_ids = ids - found_ids
          klass.all.raise_record_not_found_exception!(ids, records.size, ids.size, primary_key, not_found_ids)
        else
          replace(records)
        end
      end

      def reset
        super
        @target = []
        @replaced_or_added_targets = Set.new.compare_by_identity
        @association_ids = nil
      end

      def find(*args)
        if options[:inverse_of] && loaded?
          args_flatten = args.flatten
          model = scope.model

          if args_flatten.blank?
            error_message = "Couldn't find #{model.name} without an ID"
            raise RecordNotFound.new(error_message, model.name, model.primary_key, args)
          end

          result = find_by_scan(*args)

          result_size = Array(result).size
          if !result || result_size != args_flatten.size
            scope.raise_record_not_found_exception!(args_flatten, result_size, args_flatten.size)
          else
            result
          end
        else
          scope.find(*args)
        end
      end

      def build(attributes = nil, &block)
        if attributes.is_a?(Array)
          attributes.collect { |attr| build(attr, &block) }
        else
          add_to_target(build_record(attributes, &block), replace: true)
        end
      end

      # Add +records+ to this association. Since +<<+ flattens its argument list
      # and inserts each record, +push+ and +concat+ behave identically.
      def concat(*records)
        records = records.flatten
        if owner.new_record?
          skip_strict_loading { load_target }
          concat_records(records)
        else
          transaction { concat_records(records) }
        end
      end

      # Removes all records from the association without calling callbacks
      # on the associated records. It honors the +:dependent+ option. However
      # if the +:dependent+ value is +:destroy+ then in that case the +:delete_all+
      # deletion strategy for the association is applied.
      #
      # You can force a particular deletion strategy by passing a parameter.
      #
      # Example:
      #
      # @author.books.delete_all(:nullify)
      # @author.books.delete_all(:delete_all)
      #
      # See delete for more info.
      def delete_all(dependent = nil)
        if dependent && ![:nullify, :delete_all].include?(dependent)
          raise ArgumentError, "Valid values are :nullify or :delete_all"
        end

        dependent = if dependent
          dependent
        elsif options[:dependent] == :destroy
          :delete_all
        else
          options[:dependent]
        end

        delete_or_nullify_all_records(dependent).tap do
          reset
          loaded!
        end
      end

      # Destroy all the records from this association.
      #
      # See destroy for more info.
      def destroy_all
        destroy(load_target).tap do
          reset
          loaded!
        end
      end

      # Removes +records+ from this association calling +before_remove+ and
      # +after_remove+ callbacks.
      #
      # This method is abstract in the sense that +delete_records+ has to be
      # provided by descendants. Note this method does not imply the records
      # are actually removed from the database, that depends precisely on
      # +delete_records+. They are in any case removed from the collection.
      def delete(*records)
        delete_or_destroy(records, options[:dependent])
      end

      # Deletes the +records+ and removes them from this association calling
      # +before_remove+, +after_remove+, +before_destroy+ and +after_destroy+ callbacks.
      #
      # Note that this method removes records from the database ignoring the
      # +:dependent+ option.
      def destroy(*records)
        delete_or_destroy(records, :destroy)
      end

      # Returns the size of the collection by executing a SELECT COUNT(*)
      # query if the collection hasn't been loaded, and calling
      # <tt>collection.size</tt> if it has.
      #
      # If the collection has been already loaded +size+ and +length+ are
      # equivalent. If not and you are going to need the records anyway
      # +length+ will take one less query. Otherwise +size+ is more efficient.
      #
      # This method is abstract in the sense that it relies on
      # +count_records+, which is a method descendants have to provide.
      def size
        if !find_target? || loaded?
          target.size
        elsif @association_ids
          @association_ids.size
        elsif !association_scope.group_values.empty?
          load_target.size
        elsif !association_scope.distinct_value && !target.empty?
          unsaved_records = target.select(&:new_record?)
          unsaved_records.size + count_records
        else
          count_records
        end
      end

      # Returns true if the collection is empty.
      #
      # If the collection has been loaded
      # it is equivalent to <tt>collection.size.zero?</tt>. If the
      # collection has not been loaded, it is equivalent to
      # <tt>!collection.exists?</tt>. If the collection has not already been
      # loaded and you are going to fetch the records anyway it is better to
      # check <tt>collection.length.zero?</tt>.
      def empty?
        if loaded? || @association_ids || reflection.has_active_cached_counter?
          size.zero?
        else
          target.empty? && !scope.exists?
        end
      end

      # Replace this collection with +other_array+. This will perform a diff
      # and delete/add only records that have changed.
      def replace(other_array)
        other_array.each { |val| raise_on_type_mismatch!(val) }
        original_target = skip_strict_loading { load_target }.dup

        if owner.new_record?
          replace_records(other_array, original_target)
        else
          replace_common_records_in_memory(other_array, original_target)
          if other_array != original_target
            transaction { replace_records(other_array, original_target) }
          else
            other_array
          end
        end
      end

      def include?(record)
        klass = reflection.klass
        return false unless record.is_a?(klass)

        if loaded?
          target.include?(record)
        elsif record.new_record?
          include_in_memory?(record)
        else
          record_id = klass.composite_primary_key? ? klass.primary_key.zip(record.id).to_h : record.id
          scope.exists?(record_id)
        end
      end

      def load_target
        if find_target?
          @target = merge_target_lists(find_target, target)
        end

        loaded!
        target
      end

      def add_to_target(record, skip_callbacks: false, replace: false, &block)
        replace_on_target(record, skip_callbacks, replace: replace || association_scope.distinct_value, &block)
      end

      def target=(record)
        return super unless reflection.klass.has_many_inversing

        case record
        when nil
          # It's not possible to remove the record from the inverse association.
        when Array
          super
        else
          replace_on_target(record, true, replace: true, inversing: true)
        end
      end

      def scope
        scope = super
        scope.none! if null_scope?
        scope
      end

      def null_scope?
        owner.new_record? && !foreign_key_present?
      end

      def find_from_target?
        loaded? ||
          (owner.strict_loading? && owner.strict_loading_all?) ||
          reflection.strict_loading? ||
          owner.new_record? ||
          target.any? { |record| record.new_record? || record.changed? }
      end

      def collection?
        true
      end

      private
        def transaction(&block)
          reflection.klass.transaction(&block)
        end

        # We have some records loaded from the database (persisted) and some that are
        # in-memory (memory). The same record may be represented in the persisted array
        # and in the memory array.
        #
        # So the task of this method is to merge them according to the following rules:
        #
        #   * The final array must not have duplicates
        #   * The order of the persisted array is to be preserved
        #   * Any changes made to attributes on objects in the memory array are to be preserved
        #   * Otherwise, attributes should have the value found in the database
        def merge_target_lists(persisted, memory)
          return persisted if memory.empty?

          persisted.map! do |record|
            if mem_record = memory.delete(record)

              ((record.attribute_names & mem_record.attribute_names) - mem_record.changed_attribute_names_to_save - mem_record.class._attr_readonly).each do |name|
                mem_record._write_attribute(name, record[name])
              end

              mem_record
            else
              record
            end
          end

          persisted + memory.reject(&:persisted?)
        end

        def _create_record(attributes, raise = false, &block)
          unless owner.persisted?
            raise ActiveRecord::RecordNotSaved.new("You cannot call create unless the parent is saved", owner)
          end

          if attributes.is_a?(Array)
            attributes.collect { |attr| _create_record(attr, raise, &block) }
          else
            record = build_record(attributes, &block)
            transaction do
              result = nil
              add_to_target(record) do
                result = insert_record(record, true, raise) {
                  @_was_loaded = loaded?
                }
              end
              raise ActiveRecord::Rollback unless result
            end
            record
          end
        end

        # Do the relevant stuff to insert the given record into the association collection.
        def insert_record(record, validate = true, raise = false, &block)
          if raise
            record.save!(validate: validate, &block)
          else
            record.save(validate: validate, &block)
          end
        end

        def delete_or_destroy(records, method)
          return if records.empty?
          records = find(records) if records.any? { |record| record.kind_of?(Integer) || record.kind_of?(String) }
          records = records.flatten
          records.each { |record| raise_on_type_mismatch!(record) }
          existing_records = records.reject(&:new_record?)

          if existing_records.empty?
            remove_records(existing_records, records, method)
          else
            transaction { remove_records(existing_records, records, method) }
          end
        end

        def remove_records(existing_records, records, method)
          catch(:abort) do
            records.each { |record| callback(:before_remove, record) }
          end || return

          delete_records(existing_records, method) if existing_records.any?
          @target -= records
          @association_ids = nil

          records.each { |record| callback(:after_remove, record) }
        end

        # Delete the given records from the association,
        # using one of the methods +:destroy+, +:delete_all+
        # or +:nullify+ (or +nil+, in which case a default is used).
        def delete_records(records, method)
          raise NotImplementedError
        end

        def replace_records(new_target, original_target)
          delete(difference(target, new_target))

          unless concat(difference(new_target, target))
            @target = original_target
            raise RecordNotSaved, "Failed to replace #{reflection.name} because one or more of the " \
                                  "new records could not be saved."
          end

          target
        end

        def replace_common_records_in_memory(new_target, original_target)
          common_records = intersection(new_target, original_target)
          common_records.each do |record|
            skip_callbacks = true
            replace_on_target(record, skip_callbacks, replace: true)
          end
        end

        def concat_records(records, raise = false)
          result = true

          records.each do |record|
            raise_on_type_mismatch!(record)
            add_to_target(record) do
              unless owner.new_record?
                result &&= insert_record(record, true, raise) {
                  @_was_loaded = loaded?
                }
              end
            end
          end

          raise ActiveRecord::Rollback unless result

          records
        end

        def replace_on_target(record, skip_callbacks, replace:, inversing: false)
          if replace && (!record.new_record? || @replaced_or_added_targets.include?(record))
            index = @target.index(record)
          end

          catch(:abort) do
            callback(:before_add, record)
          end || return unless skip_callbacks

          set_inverse_instance(record)

          @_was_loaded = true

          yield(record) if block_given?

          if !index && @replaced_or_added_targets.include?(record)
            index = @target.index(record)
          end

          @replaced_or_added_targets << record if inversing || index || record.new_record?

          if index
            target[index] = record
          elsif @_was_loaded || !loaded?
            @association_ids = nil
            target << record
          end

          callback(:after_add, record) unless skip_callbacks

          record
        ensure
          @_was_loaded = nil
        end

        def callback(method, record)
          callbacks_for(method).each do |callback|
            callback.call(method, owner, record)
          end
        end

        def callbacks_for(callback_name)
          full_callback_name = "#{callback_name}_for_#{reflection.name}"
          if owner.class.respond_to?(full_callback_name)
            owner.class.send(full_callback_name)
          else
            []
          end
        end

        def include_in_memory?(record)
          if reflection.is_a?(ActiveRecord::Reflection::ThroughReflection)
            assoc = owner.association(reflection.through_reflection.name)
            assoc.reader.any? { |source|
              target_reflection = source.send(reflection.source_reflection.name)
              target_reflection.respond_to?(:include?) ? target_reflection.include?(record) : target_reflection == record
            } || target.include?(record)
          else
            target.include?(record)
          end
        end

        # If the :inverse_of option has been
        # specified, then #find scans the entire collection.
        def find_by_scan(*args)
          expects_array = args.first.kind_of?(Array)
          ids           = args.flatten.compact.map(&:to_s).uniq

          if ids.size == 1
            id = ids.first
            record = load_target.detect { |r| id == r.id.to_s }
            expects_array ? [ record ] : record
          else
            load_target.select { |r| ids.include?(r.id.to_s) }
          end
        end
    end
  end
end
