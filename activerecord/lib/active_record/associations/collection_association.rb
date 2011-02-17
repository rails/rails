require 'active_support/core_ext/array/wrap'

module ActiveRecord
  module Associations
    # = Active Record Association Collection
    #
    # AssociationCollection is an abstract class that provides common stuff to
    # ease the implementation of association proxies that represent
    # collections. See the class hierarchy in AssociationProxy.
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
      attr_reader :proxy

      def initialize(owner, reflection)
        # When scopes are created via method_missing on the proxy, they are stored so that
        # any records fetched from the database are kept around for future use.
        @scopes_cache = Hash.new do |hash, method|
          hash[method] = { }
        end

        super

        @proxy = CollectionProxy.new(self)
      end

      def reset
        @loaded = false
        @target = []
        @scopes_cache.clear
      end

      def select(select = nil)
        if block_given?
          load_target.select.each { |e| yield e }
        else
          scoped.select(select)
        end
      end

      def find(*args)
        if @reflection.options[:finder_sql]
          find_by_scan(*args)
        else
          scoped.find(*args)
        end
      end

      def first(*args)
        first_or_last(:first, *args)
      end

      def last(*args)
        first_or_last(:last, *args)
      end

      def build(attributes = {}, &block)
        build_or_create(attributes, :build, &block)
      end

      def create(attributes = {}, &block)
        unless @owner.persisted?
          raise ActiveRecord::RecordNotSaved, "You cannot call create unless the parent is saved"
        end

        build_or_create(attributes, :create, &block)
      end

      def create!(attrs = {}, &block)
        record = create(attrs, &block)
        Array.wrap(record).each(&:save!)
        record
      end

      # Add +records+ to this association.  Returns +self+ so method calls may be chained.
      # Since << flattens its argument list and inserts each record, +push+ and +concat+ behave identically.
      def concat(*records)
        result = true
        load_target if @owner.new_record?

        transaction do
          records.flatten.each do |record|
            raise_on_type_mismatch(record)
            add_to_target(record) do |r|
              result &&= insert_record(record) unless @owner.new_record?
            end
          end
        end

        result && records
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
        @reflection.klass.transaction(*args) do
          yield
        end
      end

      # Remove all records from this association
      #
      # See delete for more info.
      def delete_all
        delete(load_target).tap do
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

      # Calculate sum using SQL, not Enumerable
      def sum(*args)
        if block_given?
          scoped.sum(*args) { |*block_args| yield(*block_args) }
        else
          scoped.sum(*args)
        end
      end

      # Count all records using SQL. If the +:counter_sql+ or +:finder_sql+ option is set for the
      # association, it will be used for the query. Otherwise, construct options and pass them with
      # scope to the target class's +count+.
      def count(column_name = nil, options = {})
        column_name, options = nil, column_name if column_name.is_a?(Hash)

        if @reflection.options[:counter_sql] || @reflection.options[:finder_sql]
          unless options.blank?
            raise ArgumentError, "If finder_sql/counter_sql is used then options cannot be passed"
          end

          @reflection.klass.count_by_sql(custom_counter_sql)
        else
          if @reflection.options[:uniq]
            # This is needed because 'SELECT count(DISTINCT *)..' is not valid SQL.
            column_name ||= @reflection.klass.primary_key
            options.merge!(:distinct => true)
          end

          value = scoped.count(column_name, options)

          limit  = @reflection.options[:limit]
          offset = @reflection.options[:offset]

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
        delete_or_destroy(records, @reflection.options[:dependent])
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
        if @owner.new_record? || (loaded? && !@reflection.options[:uniq])
          @target.size
        elsif !loaded? && @reflection.options[:group]
          load_target.size
        elsif !loaded? && !@reflection.options[:uniq] && @target.is_a?(Array)
          unsaved_records = @target.select { |r| r.new_record? }
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

      # Equivalent to <tt>collection.size.zero?</tt>. If the collection has
      # not been already loaded and you are going to fetch the records anyway
      # it is better to check <tt>collection.length.zero?</tt>.
      def empty?
        size.zero?
      end

      def any?
        if block_given?
          load_target.any? { |*block_args| yield(*block_args) }
        else
          !empty?
        end
      end

      # Returns true if the collection has more than 1 record. Equivalent to collection.size > 1.
      def many?
        if block_given?
          load_target.many? { |*block_args| yield(*block_args) }
        else
          size > 1
        end
      end

      def uniq(collection = load_target)
        seen = {}
        collection.find_all do |record|
          seen[record.id] = true unless seen.key?(record.id)
        end
      end

      # Replace this collection with +other_array+
      # This will perform a diff and delete/add only records that have changed.
      def replace(other_array)
        other_array.each { |val| raise_on_type_mismatch(val) }
        original_target = load_target.dup

        transaction do
          delete(@target - other_array)

          unless concat(other_array - @target)
            @target = original_target
            raise RecordNotSaved, "Failed to replace #{@reflection.name} because one or more of the " \
                                  "new records could not be saved."
          end
        end
      end

      def include?(record)
        if record.is_a?(@reflection.klass)
          if record.new_record?
            include_in_memory?(record)
          else
            load_target if @reflection.options[:finder_sql]
            loaded? ? @target.include?(record) : scoped.exists?(record)
          end
        else
          false
        end
      end

      def cached_scope(method, args)
        @scopes_cache[method][args] ||= scoped.readonly(nil).send(method, *args)
      end

      def association_scope
        options = @reflection.options.slice(:order, :limit, :joins, :group, :having, :offset)
        super.apply_finder_options(options)
      end

      def load_target
        if find_target?
          targets = []

          begin
            targets = find_target
          rescue ActiveRecord::RecordNotFound
            reset
          end

          @target = merge_target_lists(targets, @target)
        end

        loaded!
        target
      end

      def add_to_target(record)
        transaction do
          callback(:before_add, record)
          yield(record) if block_given?

          if @reflection.options[:uniq] && index = @target.index(record)
            @target[index] = record
          else
            @target << record
          end

          callback(:after_add, record)
          set_inverse_instance(record)
        end

        record
      end

      private

        def select_value
          super || uniq_select_value
        end

        def uniq_select_value
          @reflection.options[:uniq] && "DISTINCT #{@reflection.quoted_table_name}.*"
        end

        def custom_counter_sql
          if @reflection.options[:counter_sql]
            interpolate(@reflection.options[:counter_sql])
          else
            # replace the SELECT clause with COUNT(*), preserving any hints within /* ... */
            interpolate(@reflection.options[:finder_sql]).sub(/SELECT\b(\/\*.*?\*\/ )?(.*)\bFROM\b/im) { "SELECT #{$1}COUNT(*) FROM" }
          end
        end

        def custom_finder_sql
          interpolate(@reflection.options[:finder_sql])
        end

        def find_target
          records =
            if @reflection.options[:finder_sql]
              @reflection.klass.find_by_sql(custom_finder_sql)
            else
              find(:all)
            end

          records = @reflection.options[:uniq] ? uniq(records) : records
          records.each { |record| set_inverse_instance(record) }
          records
        end

        def merge_target_lists(loaded, existing)
          return loaded if existing.empty?
          return existing if loaded.empty?

          loaded.map do |f|
            i = existing.index(f)
            if i
              existing.delete_at(i).tap do |t|
                keys = ["id"] + t.changes.keys + (f.attribute_names - t.attribute_names)
                # FIXME: this call to attributes causes many NoMethodErrors
                attributes = f.attributes
                (attributes.keys - keys).each do |k|
                  t.send("#{k}=", attributes[k])
                end
              end
            else
              f
            end
          end + existing
        end

        def build_or_create(attributes, method)
          records = Array.wrap(attributes).map do |attrs|
            record = build_record(attrs)

            add_to_target(record) do
              yield(record) if block_given?
              insert_record(record) if method == :create
            end
          end

          attributes.is_a?(Array) ? records : records.first
        end

        # Do the relevant stuff to insert the given record into the association collection.
        def insert_record(record, validate = true)
          raise NotImplementedError
        end

        def build_record(attributes)
          @reflection.build_association(scoped.scope_for_create.merge(attributes))
        end

        def delete_or_destroy(records, method)
          records = records.flatten
          records.each { |record| raise_on_type_mismatch(record) }
          existing_records = records.reject { |r| r.new_record? }

          transaction do
            records.each { |record| callback(:before_remove, record) }

            delete_records(existing_records, method) if existing_records.any?
            records.each { |record| @target.delete(record) }

            records.each { |record| callback(:after_remove, record) }
          end
        end

        # Delete the given records from the association, using one of the methods :destroy,
        # :delete_all or :nullify (or nil, in which case a default is used).
        def delete_records(records, method)
          raise NotImplementedError
        end

        def callback(method, record)
          callbacks_for(method).each do |callback|
            case callback
            when Symbol
              @owner.send(callback, record)
            when Proc
              callback.call(@owner, record)
            else
              callback.send(method, @owner, record)
            end
          end
        end

        def callbacks_for(callback_name)
          full_callback_name = "#{callback_name}_for_#{@reflection.name}"
          @owner.class.send(full_callback_name.to_sym) || []
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
              @owner.new_record? ||
              @reflection.options[:finder_sql] ||
              @target.any? { |record| record.new_record? || record.changed? } ||
              args.first.kind_of?(Integer))
          end
        end

        def include_in_memory?(record)
          if @reflection.is_a?(ActiveRecord::Reflection::ThroughReflection)
            @owner.send(@reflection.through_reflection.name).any? { |source|
              target = source.send(@reflection.source_reflection.name)
              target.respond_to?(:include?) ? target.include?(record) : target == record
            } || @target.include?(record)
          else
            @target.include?(record)
          end
        end

        # If using a custom finder_sql, #find scans the entire collection.
        def find_by_scan(*args)
          expects_array = args.first.kind_of?(Array)
          ids           = args.flatten.compact.uniq.map { |arg| arg.to_i }

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

          collection = fetch_first_or_last_using_find?(args) ? scoped : load_target
          collection.send(type, *args)
        end
    end
  end
end
