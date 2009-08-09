require 'set'

module ActiveRecord
  module Associations
    # AssociationCollection is an abstract class that provides common stuff to
    # ease the implementation of association proxies that represent
    # collections. See the class hierarchy in AssociationProxy.
    #
    # You need to be careful with assumptions regarding the target: The proxy
    # does not fetch records from the database until it needs them, but new
    # ones created with +build+ are added to the target. So, the target may be
    # non-empty and still lack children waiting to be read from the database.
    # If you look directly to the database you cannot assume that's the entire
    # collection because new records may have beed added to the target, etc.
    #
    # If you need to work on all current children, new and existing records,
    # +load_target+ and the +loaded+ flag are your friends.
    class AssociationCollection < AssociationProxy #:nodoc:
      def initialize(owner, reflection)
        super
        construct_sql
      end
      
      def find(*args)
        options = args.extract_options!

        # If using a custom finder_sql, scan the entire collection.
        if @reflection.options[:finder_sql]
          expects_array = args.first.kind_of?(Array)
          ids           = args.flatten.compact.uniq.map { |arg| arg.to_i }

          if ids.size == 1
            id = ids.first
            record = load_target.detect { |r| id == r.id }
            expects_array ? [ record ] : record
          else
            load_target.select { |r| ids.include?(r.id) }
          end
        else
          conditions = "#{@finder_sql}"
          if sanitized_conditions = sanitize_sql(options[:conditions])
            conditions << " AND (#{sanitized_conditions})"
          end
          
          options[:conditions] = conditions

          if options[:order] && @reflection.options[:order]
            options[:order] = "#{options[:order]}, #{@reflection.options[:order]}"
          elsif @reflection.options[:order]
            options[:order] = @reflection.options[:order]
          end
          
          # Build options specific to association
          construct_find_options!(options)
          
          merge_options_from_reflection!(options)
          
          # Pass through args exactly as we received them.
          args << options
          @reflection.klass.find(*args)
        end
      end

      # Fetches the first one using SQL if possible.
      def first(*args)
        if fetch_first_or_last_using_find?(args)
          find(:first, *args)
        else
          load_target unless loaded?
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
          @target.to_ary
        else
          Array(@target)
        end
      end

      def reset
        reset_target!
        @loaded = false
      end

      def build(attributes = {}, &block)
        if attributes.is_a?(Array)
          attributes.collect { |attr| build(attr, &block) }
        else
          build_record(attributes) do |record|
            block.call(record) if block_given?
            set_belongs_to_association_for(record)
          end
        end
      end

      # Add +records+ to this association.  Returns +self+ so method calls may be chained.  
      # Since << flattens its argument list and inserts each record, +push+ and +concat+ behave identically.
      def <<(*records)
        result = true
        load_target if @owner.new_record?

        transaction do
          flatten_deeper(records).each do |record|
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
      #   Author.find(:first).books.transaction do
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
      end
      
      # Calculate sum using SQL, not Enumerable
      def sum(*args)
        if block_given?
          calculate(:sum, *args) { |*block_args| yield(*block_args) }
        else
          calculate(:sum, *args)
        end
      end

      # Count all records using SQL. If the +:counter_sql+ option is set for the association, it will
      # be used for the query. If no +:counter_sql+ was supplied, but +:finder_sql+ was set, the
      # descendant's +construct_sql+ method will have set :counter_sql automatically.
      # Otherwise, construct options and pass them with scope to the target class's +count+.
      def count(*args)
        if @reflection.options[:counter_sql]
          @reflection.klass.count_by_sql(@counter_sql)
        else
          column_name, options = @reflection.klass.send(:construct_count_options_from_args, *args)
          if @reflection.options[:uniq]
            # This is needed because 'SELECT count(DISTINCT *)..' is not valid SQL.
            column_name = "#{@reflection.quoted_table_name}.#{@reflection.klass.primary_key}" if column_name == :all
            options.merge!(:distinct => true)
          end

          value = @reflection.klass.send(:with_scope, construct_scope) { @reflection.klass.count(column_name, options) }

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
        remove_records(records) do |records, old_records|
          delete_records(old_records) if old_records.any?
          records.each { |record| @target.delete(record) }
        end
      end

      # Destroy +records+ and remove them from this association calling
      # +before_remove+ and +after_remove+ callbacks.
      #
      # Note that this method will _always_ remove records from the database
      # ignoring the +:dependent+ option.
      def destroy(*records)
        records = find(records) if records.any? {|record| record.kind_of?(Fixnum) || record.kind_of?(String)}
        remove_records(records) do |records, old_records|
          old_records.each { |record| record.destroy }
        end

        load_target
      end

      # Removes all records from this association.  Returns +self+ so method calls may be chained.
      def clear
        return self if length.zero? # forces load_target if it hasn't happened already

        if @reflection.options[:dependent] && @reflection.options[:dependent] == :destroy
          destroy_all
        else          
          delete_all
        end

        self
      end

      # Destory all the records from this association.
      #
      # See destroy for more info.
      def destroy_all
        load_target
        destroy(@target)
        reset_target!
      end

      def create(attrs = {})
        if attrs.is_a?(Array)
          attrs.collect { |attr| create(attr) }
        else
          create_record(attrs) do |record|
            yield(record) if block_given?
            record.save
          end
        end
      end

      def create!(attrs = {})
        create_record(attrs) do |record|
          yield(record) if block_given?
          record.save!
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

      def uniq(collection = self)
        seen = Set.new
        collection.inject([]) do |kept, record|
          unless seen.include?(record.id)
            kept << record
            seen << record.id
          end
          kept
        end
      end

      # Replace this collection with +other_array+
      # This will perform a diff and delete/add only records that have changed.
      def replace(other_array)
        other_array.each { |val| raise_on_type_mismatch(val) }

        load_target
        other   = other_array.size < 100 ? other_array : other_array.to_set
        current = @target.size < 100 ? @target : @target.to_set

        transaction do
          delete(@target.select { |v| !other.include?(v) })
          concat(other_array.select { |v| !current.include?(v) })
        end
      end

      def include?(record)
        return false unless record.is_a?(@reflection.klass)
        load_target if @reflection.options[:finder_sql] && !loaded?
        return @target.include?(record) if loaded?
        exists?(record)
      end

      def proxy_respond_to?(method, include_private = false)
        super || @reflection.klass.respond_to?(method, include_private)
      end

      protected
        def construct_find_options!(options)
        end
        
        def load_target
          if !@owner.new_record? || foreign_key_present
            begin
              if !loaded?
                if @target.is_a?(Array) && @target.any?
                  @target = find_target + @target.find_all {|t| t.new_record? }
                else
                  @target = find_target
                end
              end
            rescue ActiveRecord::RecordNotFound
              reset
            end
          end

          loaded if target
          target
        end
        
        def method_missing(method, *args)
          if @target.respond_to?(method) || (!@reflection.klass.respond_to?(method) && Class.respond_to?(method))
            if block_given?
              super { |*block_args| yield(*block_args) }
            else
              super
            end
          elsif @reflection.klass.scopes.include?(method)
            @reflection.klass.scopes[method].call(self, *args)
          else          
            with_scope(construct_scope) do
              if block_given?
                @reflection.klass.send(method, *args) { |*block_args| yield(*block_args) }
              else
                @reflection.klass.send(method, *args)
              end
            end
          end
        end

        # overloaded in derived Association classes to provide useful scoping depending on association type.
        def construct_scope
          {}
        end

        def reset_target!
          @target = Array.new
        end

        def find_target
          records =
            if @reflection.options[:finder_sql]
              @reflection.klass.find_by_sql(@finder_sql)
            else
              find(:all)
            end

          @reflection.options[:uniq] ? uniq(records) : records
        end

      private

        def create_record(attrs)
          attrs.update(@reflection.options[:conditions]) if @reflection.options[:conditions].is_a?(Hash)
          ensure_owner_is_not_new
          record = @reflection.klass.send(:with_scope, :create => construct_scope[:create]) do
            @reflection.build_association(attrs)
          end
          if block_given?
            add_record_to_target_with_callbacks(record) { |*block_args| yield(*block_args) }
          else
            add_record_to_target_with_callbacks(record)
          end
        end

        def build_record(attrs)
          attrs.update(@reflection.options[:conditions]) if @reflection.options[:conditions].is_a?(Hash)
          record = @reflection.build_association(attrs)
          if block_given?
            add_record_to_target_with_callbacks(record) { |*block_args| yield(*block_args) }
          else
            add_record_to_target_with_callbacks(record)
          end
        end

        def add_record_to_target_with_callbacks(record)
          callback(:before_add, record)
          yield(record) if block_given?
          @target ||= [] unless loaded?
          @target << record unless @reflection.options[:uniq] && @target.include?(record)
          callback(:after_add, record)
          record
        end

        def remove_records(*records)
          records = flatten_deeper(records)
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
            ActiveSupport::Callbacks::Callback.new(method, callback, record).call(@owner, record)
          end
        end

        def callbacks_for(callback_name)
          full_callback_name = "#{callback_name}_for_#{@reflection.name}"
          @owner.class.read_inheritable_attribute(full_callback_name.to_sym) || []
        end   
        
        def ensure_owner_is_not_new
          if @owner.new_record?
            raise ActiveRecord::RecordNotSaved, "You cannot call create unless the parent is saved"
          end
        end

        def fetch_first_or_last_using_find?(args)
          args.first.kind_of?(Hash) || !(loaded? || @owner.new_record? || @reflection.options[:finder_sql] ||
                                         @target.any? { |record| record.new_record? } || args.first.kind_of?(Integer))
        end
    end
  end
end
