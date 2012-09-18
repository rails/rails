module ActiveRecord
  module Associations
    # = Active Record Association Collection
    #
    # CollectionAssociation is an abstract class that provides common stuff to
    # ease the implementation of association proxies that represent
    # collections. See the class hierarchy in AssociationProxy.
    #
    #   CollectionAssociation:
    #     HasAndBelongsToManyAssociation => has_and_belongs_to_many
    #     HasManyAssociation => has_many
    #       HasManyThroughAssociation + ThroughAssociation => has_many :through
    #
    # CollectionAssociation class provides common methods to the collections
    # defined by +has_and_belongs_to_many+, +has_many+ or +has_many+ with
    # +:through association+ option.
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
          klass.uncached { reload }
        elsif stale_target?
          reload
        end

        CollectionProxy.new(self)
      end

      # Implements the writer method, e.g. foo.items= for Foo.has_many :items
      def writer(records)
        replace(records)
      end

      # Implements the ids reader method, e.g. foo.item_ids for Foo.has_many :items
      def ids_reader
        if loaded? || options[:finder_sql]
          load_target.map do |record|
            record.send(reflection.association_primary_key)
          end
        else
          column  = "#{reflection.quoted_table_name}.#{reflection.association_primary_key}"
          scope.pluck(column)
        end
      end

      # Implements the ids writer method, e.g. foo.item_ids= for Foo.has_many :items
      def ids_writer(ids)
        pk_column = reflection.primary_key_column
        ids = Array(ids).reject { |id| id.blank? }
        ids.map! { |i| pk_column.type_cast(i) }
        replace(klass.find(ids).index_by { |r| r.id }.values_at(*ids))
      end

      def reset
        super
        @target = []
      end

      def select(select = nil)
        if block_given?
          load_target.select.each { |e| yield e }
        else
          scope.select(select)
        end
      end

      def find(*args)
        if block_given?
          load_target.find(*args) { |*block_args| yield(*block_args) }
        else
          if options[:finder_sql]
            find_by_scan(*args)
          else
            scope.find(*args)
          end
        end
      end

      def first(*args)
        first_or_last(:first, *args)
      end

      def last(*args)
        first_or_last(:last, *args)
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

      def create(attributes = {}, &block)
        create_record(attributes, &block)
      end

      def create!(attributes = {}, &block)
        create_record(attributes, true, &block)
      end

      # Add +records+ to this association. Returns +self+ so method calls may
      # be chained. Since << flattens its argument list and inserts each record,
      # +push+ and +concat+ behave identically.
      def concat(*records)
        load_target if owner.new_record?

        if owner.new_record?
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

      # Remove all records from this association.
      #
      # See delete for more info.
      def delete_all
        delete(:all).tap do
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

      # Calculate sum using SQL, not Enumerable.
      def sum(*args)
        if block_given?
          scope.sum(*args) { |*block_args| yield(*block_args) }
        else
          scope.sum(*args)
        end
      end

      # Count all records using SQL. If the +:counter_sql+ or +:finder_sql+ option is set for the
      # association, it will be used for the query. Otherwise, construct options and pass them with
      # scope to the target class's +count+.
      def count(column_name = nil, count_options = {})
        column_name, count_options = nil, column_name if column_name.is_a?(Hash)

        if options[:counter_sql] || options[:finder_sql]
          unless count_options.blank?
            raise ArgumentError, "If finder_sql/counter_sql is used then options cannot be passed"
          end

          reflection.klass.count_by_sql(custom_counter_sql)
        else
          if association_scope.uniq_value
            # This is needed because 'SELECT count(DISTINCT *)..' is not valid SQL.
            column_name ||= reflection.klass.primary_key
            count_options[:distinct] = true
          end

          value = scope.count(column_name, count_options)

          limit  = options[:limit]
          offset = options[:offset]

          if limit || offset
            [ [value - offset.to_i, 0].max, limit.to_i ].min
          else
            value
          end
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
        dependent = options[:dependent]

        if records.first == :all
          if loaded? || dependent == :destroy
            delete_or_destroy(load_target, dependent)
          else
            delete_records(:all, dependent)
          end
        else
          records = find(records) if records.any? { |record| record.kind_of?(Fixnum) || record.kind_of?(String) }
          delete_or_destroy(records, dependent)
        end
      end

      # Destroy +records+ and remove them from this association calling
      # +before_remove+ and +after_remove+ callbacks.
      #
      # Note that this method will _always_ remove records from the database
      # ignoring the +:dependent+ option.
      def destroy(*records)
        records = find(records) if records.any? { |record| record.kind_of?(Fixnum) || record.kind_of?(String) }
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
          if association_scope.uniq_value
            target.uniq.size
          else
            target.size
          end
        elsif !loaded? && !association_scope.group_values.empty?
          load_target.size
        elsif !loaded? && !association_scope.uniq_value && target.is_a?(Array)
          unsaved_records = target.select { |r| r.new_record? }
          unsaved_records.size + count_records
        else
          count_records
        end
      end

      # Returns the size of the collection calling +size+ on the target.
      #
      # If the collection has been already loaded +length+ and +size+ are
      # equivalent. If not and you are going to need the records anyway this
      # method will take one less query. Otherwise +size+ is more efficient.
      def length
        load_target.size
      end

      # Returns true if the collection is empty.
      #
      # If the collection has been loaded or the <tt>:counter_sql</tt> option
      # is provided, it is equivalent to <tt>collection.size.zero?</tt>. If the
      # collection has not been loaded, it is equivalent to
      # <tt>collection.exists?</tt>. If the collection has not already been
      # loaded and you are going to fetch the records anyway it is better to
      # check <tt>collection.length.zero?</tt>.
      def empty?
        if loaded? || options[:counter_sql]
          size.zero?
        else
          !scope.exists?
        end
      end

      # Returns true if the collections is not empty.
      # Equivalent to +!collection.empty?+.
      def any?
        if block_given?
          load_target.any? { |*block_args| yield(*block_args) }
        else
          !empty?
        end
      end

      # Returns true if the collection has more than 1 record.
      # Equivalent to +collection.size > 1+.
      def many?
        if block_given?
          load_target.many? { |*block_args| yield(*block_args) }
        else
          size > 1
        end
      end

      def uniq
        seen = {}
        load_target.find_all do |record|
          seen[record.id] = true unless seen.key?(record.id)
        end
      end

      # Replace this collection with +other_array+. This will perform a diff
      # and delete/add only records that have changed.
      def replace(other_array)
        other_array.each { |val| raise_on_type_mismatch(val) }
        original_target = load_target.dup

        if owner.new_record?
          replace_records(other_array, original_target)
        else
          transaction { replace_records(other_array, original_target) }
        end
      end

      def include?(record)
        if record.is_a?(reflection.klass)
          if record.new_record?
            include_in_memory?(record)
          else
            load_target if options[:finder_sql]
            loaded? ? target.include?(record) : scope.exists?(record)
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

      def add_to_target(record)
        callback(:before_add, record)
        yield(record) if block_given?

        if association_scope.uniq_value && index = @target.index(record)
          @target[index] = record
        else
          @target << record
        end

        callback(:after_add, record)
        set_inverse_instance(record)

        record
      end

      private

        def custom_counter_sql
          if options[:counter_sql]
            interpolate(options[:counter_sql])
          else
            # replace the SELECT clause with COUNT(SELECTS), preserving any hints within /* ... */
            interpolate(options[:finder_sql]).sub(/SELECT\b(\/\*.*?\*\/ )?(.*)\bFROM\b/im) do
              count_with = $2.to_s
              count_with = '*' if count_with.blank? || count_with =~ /,/ || count_with =~ /\.\*/
              "SELECT #{$1}COUNT(#{count_with}) FROM"
            end
          end
        end

        def custom_finder_sql
          interpolate(options[:finder_sql])
        end

        def find_target
          records =
            if options[:finder_sql]
              reflection.klass.find_by_sql(custom_finder_sql)
            else
              scope.to_a
            end

          records.each { |record| set_inverse_instance(record) }
          records
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

              (record.attribute_names - mem_record.changes.keys).each do |name|
                mem_record[name] = record[name]
              end

              mem_record
            else
              record
            end
          end

          persisted + memory
        end

        def create_record(attributes, raise = false, &block)
          unless owner.persisted?
            raise ActiveRecord::RecordNotSaved, "You cannot call create unless the parent is saved"
          end

          if attributes.is_a?(Array)
            attributes.collect { |attr| create_record(attr, raise, &block) }
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
          records.each { |record| raise_on_type_mismatch(record) }
          existing_records = records.reject { |r| r.new_record? }

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

        def concat_records(records)
          result = true

          records.flatten.each do |record|
            raise_on_type_mismatch(record)
            add_to_target(record) do |r|
              result &&= insert_record(record) unless owner.new_record?
            end
          end

          result && records
        end

        def callback(method, record)
          callbacks_for(method).each do |callback|
            case callback
            when Symbol
              owner.send(callback, record)
            when Proc
              callback.call(owner, record)
            else
              callback.send(method, owner, record)
            end
          end
        end

        def callbacks_for(callback_name)
          full_callback_name = "#{callback_name}_for_#{reflection.name}"
          owner.class.send(full_callback_name.to_sym) || []
        end

        # Should we deal with assoc.first or assoc.last by issuing an independent query to
        # the database, or by getting the target, and then taking the first/last item from that?
        #
        # If the args is just a non-empty options hash, go to the database.
        #
        # Otherwise, go to the database only if none of the following are true:
        #   * target already loaded
        #   * owner is new record
        #   * custom :finder_sql exists
        #   * target contains new or changed record(s)
        #   * the first arg is an integer (which indicates the number of records to be returned)
        def fetch_first_or_last_using_find?(args)
          if args.first.is_a?(Hash)
            true
          else
            !(loaded? ||
              owner.new_record? ||
              options[:finder_sql] ||
              target.any? { |record| record.new_record? || record.changed? } ||
              args.first.kind_of?(Integer))
          end
        end

        def include_in_memory?(record)
          if reflection.is_a?(ActiveRecord::Reflection::ThroughReflection)
            owner.send(reflection.through_reflection.name).any? { |source|
              target = source.send(reflection.source_reflection.name)
              target.respond_to?(:include?) ? target.include?(record) : target == record
            } || target.include?(record)
          else
            target.include?(record)
          end
        end

        # If using a custom finder_sql, #find scans the entire collection.
        def find_by_scan(*args)
          expects_array = args.first.kind_of?(Array)
          ids           = args.flatten.compact.map{ |arg| arg.to_i }.uniq

          if ids.size == 1
            id = ids.first
            record = load_target.detect { |r| id == r.id }
            expects_array ? [ record ] : record
          else
            load_target.select { |r| ids.include?(r.id) }
          end
        end

        # Fetches the first/last using SQL if possible, otherwise from the target array.
        def first_or_last(type, *args)
          args.shift if args.first.is_a?(Hash) && args.first.empty?

          collection = fetch_first_or_last_using_find?(args) ? scope : load_target
          collection.send(type, *args).tap {|it| set_inverse_instance it }
        end
    end
  end
end
