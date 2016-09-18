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
    # the +:through association+ option.
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
    class CollectionAssociation < Association #:nodoc:
      # Implements the reader method, e.g. foo.items for Foo.has_many :items
      def reader(force_reload = false)
        if force_reload
          ActiveSupport::Deprecation.warn(<<-MSG.squish)
            Passing an argument to force an association to reload is now
            deprecated and will be removed in Rails 5.1. Please call `reload`
            on the result collection proxy instead.
          MSG

          klass.uncached { reload }
        elsif stale_target?
          reload
        end

        if null_scope?
          # Cache the proxy separately before the owner has an id
          # or else a post-save proxy will still lack the id
          @null_proxy ||= CollectionProxy.create(klass, self)
        else
          @proxy ||= CollectionProxy.create(klass, self)
        end
      end

      # Implements the writer method, e.g. foo.items= for Foo.has_many :items
      def writer(records)
        replace(records)
      end

      # Implements the ids reader method, e.g. foo.item_ids for Foo.has_many :items
      def ids_reader
        if loaded?
          load_target.map do |record|
            record.send(reflection.association_primary_key)
          end
        else
          @association_ids ||= (
            column = "#{reflection.quoted_table_name}.#{reflection.association_primary_key}"
            scope.pluck(column)
          )
        end
      end

      # Implements the ids writer method, e.g. foo.item_ids= for Foo.has_many :items
      def ids_writer(ids)
        pk_type = reflection.primary_key_type
        ids = Array(ids).reject(&:blank?)
        ids.map! { |i| pk_type.cast(i) }
        records = klass.where(reflection.association_primary_key => ids).index_by do |r|
          r.send(reflection.association_primary_key)
        end.values_at(*ids)
        replace(records)
      end

      def reset
        super
        @target = []
      end

      def find(*args)
        if block_given?
          load_target.find(*args) { |*block_args| yield(*block_args) }
        else
          if options[:inverse_of] && loaded?
            args_flatten = args.flatten
            raise RecordNotFound, "Couldn't find #{scope.klass.name} without an ID" if args_flatten.blank?
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
      end

      def build(attributes = {}, &block)
        if attributes.is_a?(Array)
          attributes.collect { |attr| build(attr, &block) }
        else
          add_to_target(build_record(attributes)) do |record|
            yield(record) if block_given?
          end
        end
      end

      # Add +records+ to this association. Returns +self+ so method calls may
      # be chained. Since << flattens its argument list and inserts each record,
      # +push+ and +concat+ behave identically.
      def concat(*records)
        records = records.flatten
        if owner.new_record?
          load_target
          concat_records(records)
        else
          transaction { concat_records(records) }
        end
      end

      # Starts a transaction in the association class's database connection.
      #
      #   class Author < ActiveRecord::Base
      #     has_many :books
      #   end
      #
      #   Author.first.books.transaction do
      #     # same effect as calling Book.transaction
      #   end
      def transaction(*args)
        reflection.klass.transaction(*args) do
          yield
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
        return if records.empty?
        _options = records.extract_options!
        dependent = _options[:dependent] || options[:dependent]

        records = find(records) if records.any? { |record| record.kind_of?(Integer) || record.kind_of?(String) }
        delete_or_destroy(records, dependent)
      end

      # Deletes the +records+ and removes them from this association calling
      # +before_remove+ , +after_remove+ , +before_destroy+ and +after_destroy+ callbacks.
      #
      # Note that this method removes records from the database ignoring the
      # +:dependent+ option.
      def destroy(*records)
        return if records.empty?
        records = find(records) if records.any? { |record| record.kind_of?(Integer) || record.kind_of?(String) }
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
          if association_scope.distinct_value
            target.uniq.size
          else
            target.size
          end
        elsif !association_scope.group_values.empty?
          load_target.size
        elsif !association_scope.distinct_value && target.is_a?(Array)
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
      # <tt>collection.exists?</tt>. If the collection has not already been
      # loaded and you are going to fetch the records anyway it is better to
      # check <tt>collection.length.zero?</tt>.
      def empty?
        if loaded?
          size.zero?
        else
          @target.blank? && !scope.exists?
        end
      end

      def distinct
        seen = {}
        load_target.find_all do |record|
          seen[record.id] = true unless seen.key?(record.id)
        end
      end

      # Replace this collection with +other_array+. This will perform a diff
      # and delete/add only records that have changed.
      def replace(other_array)
        other_array.each { |val| raise_on_type_mismatch!(val) }
        original_target = load_target.dup

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
        if record.is_a?(reflection.klass)
          if record.new_record?
            include_in_memory?(record)
          else
            loaded? ? target.include?(record) : scope.exists?(record.id)
          end
        else
          false
        end
      end

      def load_target
        if find_target?
          @target = merge_target_lists(find_target, target)
        end

        loaded!
        target
      end

      def add_to_target(record, skip_callbacks = false, &block)
        if association_scope.distinct_value
          index = @target.index(record)
        end
        replace_on_target(record, index, skip_callbacks, &block)
      end

      def replace_on_target(record, index, skip_callbacks)
        callback(:before_add, record) unless skip_callbacks

        was_loaded = loaded?
        yield(record) if block_given?

        unless !was_loaded && loaded?
          if index
            @target[index] = record
          else
            @target << record
          end
        end

        callback(:after_add, record) unless skip_callbacks
        set_inverse_instance(record)

        record
      end

      def scope(opts = {})
        scope = super()
        scope.none! if opts.fetch(:nullify, true) && null_scope?
        scope
      end

      def null_scope?
        owner.new_record? && !foreign_key_present?
      end

      def find_from_target?
        loaded? ||
          owner.new_record? ||
          target.any? { |record| record.new_record? || record.changed? }
      end

      private

        def find_target
          return scope.to_a if skip_statement_cache?

          conn = klass.connection
          sc = reflection.association_scope_cache(conn, owner) do
            StatementCache.create(conn) { |params|
              as = AssociationScope.create { params.bind }
              target_scope.merge as.scope(self, conn)
            }
          end

          binds = AssociationScope.get_bind_values(owner, reflection.chain)
          sc.execute(binds, klass, conn) do |record|
            set_inverse_instance(record)
          end
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
          return memory    if persisted.empty?

          persisted.map! do |record|
            if mem_record = memory.delete(record)

              ((record.attribute_names & mem_record.attribute_names) - mem_record.changes.keys).each do |name|
                mem_record[name] = record[name]
              end

              mem_record
            else
              record
            end
          end

          persisted + memory
        end

        def _create_record(attributes, raise = false, &block)
          unless owner.persisted?
            raise ActiveRecord::RecordNotSaved, "You cannot call create unless the parent is saved"
          end

          if attributes.is_a?(Array)
            attributes.collect { |attr| _create_record(attr, raise, &block) }
          else
            transaction do
              add_to_target(build_record(attributes)) do |record|
                yield(record) if block_given?
                insert_record(record, true, raise)
              end
            end
          end
        end

        # Do the relevant stuff to insert the given record into the association collection.
        def insert_record(record, validate = true, raise = false)
          raise NotImplementedError
        end

        def create_scope
          scope.scope_for_create.stringify_keys
        end

        def delete_or_destroy(records, method)
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
          records.each { |record| callback(:before_remove, record) }

          delete_records(existing_records, method) if existing_records.any?
          records.each { |record| target.delete(record) }

          records.each { |record| callback(:after_remove, record) }
        end

        # Delete the given records from the association, using one of the methods :destroy,
        # :delete_all or :nullify (or nil, in which case a default is used).
        def delete_records(records, method)
          raise NotImplementedError
        end

        def replace_records(new_target, original_target)
          delete(target - new_target)

          unless concat(new_target - target)
            @target = original_target
            raise RecordNotSaved, "Failed to replace #{reflection.name} because one or more of the " \
                                  "new records could not be saved."
          end

          target
        end

        def replace_common_records_in_memory(new_target, original_target)
          common_records = new_target & original_target
          common_records.each do |record|
            skip_callbacks = true
            replace_on_target(record, @target.index(record), skip_callbacks)
          end
        end

        def concat_records(records, should_raise = false)
          result = true

          records.each do |record|
            raise_on_type_mismatch!(record)
            add_to_target(record) do |rec|
              result &&= insert_record(rec, true, should_raise) unless owner.new_record?
            end
          end

          result && records
        end

        def callback(method, record)
          callbacks_for(method).each do |callback|
            callback.call(method, owner, record)
          end
        end

        def callbacks_for(callback_name)
          full_callback_name = "#{callback_name}_for_#{reflection.name}"
          owner.class.send(full_callback_name)
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
