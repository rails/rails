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
    class AssociationCollection < AssociationProxy #:nodoc:
      delegate :group, :order, :limit, :joins, :where, :preload, :eager_load, :includes, :from, :lock, :readonly, :having, :to => :scoped

      def select(select = nil)
        if block_given?
          load_target
          @target.select.each { |e| yield e }
        else
          scoped.select(select)
        end
      end

      def find(*args)
        if @reflection.options[:finder_sql]
          find_by_scan(*args)
        else
          find_by_sql(*args)
        end
      end

      # Fetches the first one using SQL if possible.
      def first(*args)
        if fetch_first_or_last_using_find?(args)
          find(:first, *args)
        else
          load_target unless loaded?
          args.shift if args.first.kind_of?(Hash) && args.first.empty?
          @target.first(*args)
        end
      end

      # Fetches the last one using SQL if possible.
      def last(*args)
        if fetch_first_or_last_using_find?(args)
          find(:last, *args)
        else
          load_target unless loaded?
          @target.last(*args)
        end
      end

      def to_ary
        load_target
        if @target.is_a?(Array)
          @target
        else
          Array.wrap(@target)
        end
      end
      alias_method :to_a, :to_ary

      def reset
        reset_target!
        reset_scopes_cache!
        @loaded = false
      end

      def build(attributes = {}, &block)
        if attributes.is_a?(Array)
          attributes.collect { |attr| build(attr, &block) }
        else
          build_record(attributes) do |record|
            block.call(record) if block_given?
            set_owner_attributes(record)
          end
        end
      end

      # Add +records+ to this association.  Returns +self+ so method calls may be chained.
      # Since << flattens its argument list and inserts each record, +push+ and +concat+ behave identically.
      def <<(*records)
        result = true
        load_target if @owner.new_record?

        transaction do
          records.flatten.each do |record|
            raise_on_type_mismatch(record)
            add_record_to_target_with_callbacks(record) do |r|
              result &&= insert_record(record) unless @owner.new_record?
            end
          end
        end

        result && self
      end

      alias_method :push, :<<
      alias_method :concat, :<<

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
        load_target
        delete(@target)
        reset_target!
        reset_scopes_cache!
      end

      # Calculate sum using SQL, not Enumerable
      def sum(*args)
        if block_given?
          calculate(:sum, *args) { |*block_args| yield(*block_args) }
        else
          calculate(:sum, *args)
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
            column_name = "#{@reflection.quoted_table_name}.#{@reflection.klass.primary_key}" unless column_name
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
        remove_records(records) do |_records, old_records|
          delete_records(old_records) if old_records.any?
          _records.each { |record| @target.delete(record) }
        end
      end

      # Destroy +records+ and remove them from this association calling
      # +before_remove+ and +after_remove+ callbacks.
      #
      # Note that this method will _always_ remove records from the database
      # ignoring the +:dependent+ option.
      def destroy(*records)
        records = find(records) if records.any? {|record| record.kind_of?(Fixnum) || record.kind_of?(String)}
        remove_records(records) do |_records, old_records|
          old_records.each { |record| record.destroy }
        end

        load_target
      end

      # Removes all records from this association.  Returns +self+ so method calls may be chained.
      def clear
        unless length.zero? # forces load_target if it hasn't happened already
          if @reflection.options[:dependent] == :destroy
            destroy_all
          else
            delete_all
          end
        end

        self
      end

      # Destroy all the records from this association.
      #
      # See destroy for more info.
      def destroy_all
        load_target
        destroy(@target).tap do
          reset_target!
          reset_scopes_cache!
        end
      end

      def create(attrs = {})
        if attrs.is_a?(Array)
          attrs.collect { |attr| create(attr) }
        else
          create_record(attrs) do |record|
            yield(record) if block_given?
            insert_record(record, false)
          end
        end
      end

      def create!(attrs = {})
        create_record(attrs) do |record|
          yield(record) if block_given?
          insert_record(record, true)
        end
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
          method_missing(:any?) { |*block_args| yield(*block_args) }
        else
          !empty?
        end
      end

      # Returns true if the collection has more than 1 record. Equivalent to collection.size > 1.
      def many?
        if block_given?
          method_missing(:many?) { |*block_args| yield(*block_args) }
        else
          size > 1
        end
      end

      def uniq(collection = self)
        seen = {}
        collection.find_all do |record|
          seen[record.id] = true unless seen.key?(record.id)
        end
      end

      # Replace this collection with +other_array+
      # This will perform a diff and delete/add only records that have changed.
      def replace(other_array)
        other_array.each { |val| raise_on_type_mismatch(val) }

        load_target

        transaction do
          delete(@target - other_array)

          unless concat(other_array - @target)
            raise RecordNotSaved, "Failed to replace #{@reflection.name} because one or more of the "
                                  "new records could not be saved."
          end
        end
      end

      def include?(record)
        return false unless record.is_a?(@reflection.klass)
        return include_in_memory?(record) if record.new_record?
        load_target if @reflection.options[:finder_sql] && !loaded?
        loaded? ? @target.include?(record) : exists?(record)
      end

      def respond_to?(method, include_private = false)
        super || @reflection.klass.respond_to?(method, include_private)
      end

      protected

        def association_scope
          options = @reflection.options.slice(:order, :limit, :joins, :group, :having, :offset)
          super.apply_finder_options(options)
        end

        def select_value
          super || uniq_select_value
        end

        def uniq_select_value
          @reflection.options[:uniq] && "DISTINCT #{@reflection.quoted_table_name}.*"
        end

        def load_target
          if (!@owner.new_record? || foreign_key_present?) && !loaded?
            targets = []

            begin
              targets = find_target
            rescue ActiveRecord::RecordNotFound
              reset
            end

            @target = merge_target_lists(targets, @target)
          end

          loaded
          target
        end

        def method_missing(method, *args, &block)
          match = DynamicFinderMatch.match(method)
          if match && match.creator?
            attributes = match.attribute_names
            return send(:"find_by_#{attributes.join('_and_')}", *args) || create(Hash[attributes.zip(args)])
          end

          if @target.respond_to?(method) || (!@reflection.klass.respond_to?(method) && Class.respond_to?(method))
            super
          elsif @reflection.klass.scopes[method]
            @_scopes_cache ||= {}
            @_scopes_cache[method] ||= {}
            @_scopes_cache[method][args] ||= scoped.readonly(nil).send(method, *args)
          else
            scoped.readonly(nil).send(method, *args, &block)
          end
        end

        def custom_counter_sql
          if @reflection.options[:counter_sql]
            counter_sql = @reflection.options[:counter_sql]
          else
            # replace the SELECT clause with COUNT(*), preserving any hints within /* ... */
            counter_sql = @reflection.options[:finder_sql].sub(/SELECT\b(\/\*.*?\*\/ )?(.*)\bFROM\b/im) { "SELECT #{$1}COUNT(*) FROM" }
          end

          interpolate_sql(counter_sql)
        end

        def custom_finder_sql
          interpolate_sql(@reflection.options[:finder_sql])
        end

        def reset_target!
          @target = []
        end

        def reset_scopes_cache!
          @_scopes_cache = {}
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

        def add_record_to_target_with_callbacks(record)
          callback(:before_add, record)
          yield(record) if block_given?
          @target ||= [] unless loaded?
          if @reflection.options[:uniq] && index = @target.index(record)
            @target[index] = record
          else
            @target << record
          end
          callback(:after_add, record)
          set_inverse_instance(record)
          record
        end

      private
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

        # Do the relevant stuff to insert the given record into the association collection. The
        # force param specifies whether or not an exception should be raised on failure. The
        # validate param specifies whether validation should be performed (if force is false).
        def insert_record(record, force = true, validate = true)
          raise NotImplementedError
        end

        def save_record(record, force, validate)
          force ? record.save! : record.save(:validate => validate)
        end

        def create_record(attrs, &block)
          ensure_owner_is_persisted!

          transaction do
            scoped.scoping { build_record(attrs, &block) }
          end
        end

        def build_record(attrs, &block)
          attrs.update(@reflection.options[:conditions]) if @reflection.options[:conditions].is_a?(Hash)
          record = @reflection.build_association(attrs)
          add_record_to_target_with_callbacks(record, &block)
        end

        def remove_records(*records)
          records = records.flatten
          records.each { |record| raise_on_type_mismatch(record) }

          transaction do
            records.each { |record| callback(:before_remove, record) }
            old_records = records.reject { |r| r.new_record? }
            yield(records, old_records)
            records.each { |record| callback(:after_remove, record) }
          end
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

        def ensure_owner_is_persisted!
          unless @owner.persisted?
            raise ActiveRecord::RecordNotSaved, "You cannot call create unless the parent is saved"
          end
        end

        def fetch_first_or_last_using_find?(args)
          (args.first.kind_of?(Hash) && !args.first.empty?) || !(loaded? || @owner.new_record? || @reflection.options[:finder_sql] ||
            @target.any? { |record| record.new_record? } || args.first.kind_of?(Integer))
        end

        def include_in_memory?(record)
          if @reflection.is_a?(ActiveRecord::Reflection::ThroughReflection)
            @owner.send(proxy_reflection.through_reflection.name).any? { |source|
              target = source.send(proxy_reflection.source_reflection.name)
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

        def find_by_sql(*args)
          scoped.find(*args)
        end
    end
  end
end
