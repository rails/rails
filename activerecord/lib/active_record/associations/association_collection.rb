require 'set'

module ActiveRecord
  module Associations
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
          ids           = args.flatten.compact.uniq.map(&:to_i)

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
        if fetch_first_or_last_using_find? args
          find(:first, *args)
        else
          load_target unless loaded?
          @target.first(*args)
        end
      end

      # Fetches the last one using SQL if possible.
      def last(*args)
        if fetch_first_or_last_using_find? args
          find(:last, *args)
        else
          load_target unless loaded?
          @target.last(*args)
        end
      end

      def to_ary
        load_target
        @target.to_ary
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

        @owner.transaction do
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

      # Remove all records from this association
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

      # Remove +records+ from this association.  Does not destroy +records+.
      def delete(*records)
        records = flatten_deeper(records)
        records.each { |record| raise_on_type_mismatch(record) }
        
        @owner.transaction do
          records.each { |record| callback(:before_remove, record) }
          
          old_records = records.reject {|r| r.new_record? }
          delete_records(old_records) if old_records.any?
          
          records.each do |record|
            @target.delete(record)
            callback(:after_remove, record)
          end
        end
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
      
      def destroy_all
        @owner.transaction do
          each { |record| record.destroy }
        end

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

      # Returns the size of the collection by executing a SELECT COUNT(*) query if the collection hasn't been loaded and
      # calling collection.size if it has. If it's more likely than not that the collection does have a size larger than zero
      # and you need to fetch that collection afterwards, it'll take one less SELECT query if you use length.
      def size
        if @owner.new_record? || (loaded? && !@reflection.options[:uniq])
          @target.size
        elsif !loaded? && !@reflection.options[:uniq] && @target.is_a?(Array)
          unsaved_records = @target.select { |r| r.new_record? }
          unsaved_records.size + count_records
        else
          count_records
        end
      end

      # Returns the size of the collection by loading it and calling size on the array. If you want to use this method to check
      # whether the collection is empty, use collection.length.zero? instead of collection.empty?
      def length
        load_target.size
      end

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

        @owner.transaction do
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
          record = @reflection.klass.send(:with_scope, :create => construct_scope[:create]) { @reflection.klass.new(attrs) }
          if block_given?
            add_record_to_target_with_callbacks(record) { |*block_args| yield(*block_args) }
          else
            add_record_to_target_with_callbacks(record)
          end
        end

        def build_record(attrs)
          attrs.update(@reflection.options[:conditions]) if @reflection.options[:conditions].is_a?(Hash)
          record = @reflection.klass.new(attrs)
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
          args.first.kind_of?(Hash) || !(loaded? || @owner.new_record? || @reflection.options[:finder_sql] || !@target.blank? || args.first.kind_of?(Integer))
        end
    end
  end
end
