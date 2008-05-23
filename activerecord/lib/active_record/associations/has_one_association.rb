module ActiveRecord
  module Associations
    class HasOneAssociation < BelongsToAssociation #:nodoc:
      def initialize(owner, reflection)
        super
        construct_sql
      end

      def create(attrs = {}, replace_existing = true)
        new_record(replace_existing) { |klass| klass.create(attrs) }
      end

      def create!(attrs = {}, replace_existing = true)
        new_record(replace_existing) { |klass| klass.create!(attrs) }
      end

      def build(attrs = {}, replace_existing = true)
        new_record(replace_existing) { |klass| klass.new(attrs) }
      end

      def replace(obj, dont_save = false)
        load_target

        unless @target.nil?
          if dependent? && !dont_save && @target != obj
            @target.destroy unless @target.new_record?
            @owner.clear_association_cache
          else
            @target[@reflection.primary_key_name] = nil
            @target.save unless @owner.new_record? || @target.new_record?
          end
        end

        if obj.nil?
          @target = nil
        else
          raise_on_type_mismatch(obj)
          set_belongs_to_association_for(obj)
          @target = (AssociationProxy === obj ? obj.target : obj)
        end

        @loaded = true

        unless @owner.new_record? or obj.nil? or dont_save
          return (obj.save ? self : false)
        else
          return (obj.nil? ? nil : self)
        end
      end
            
      private
        def find_target
          @reflection.klass.find(:first, 
            :conditions => @finder_sql,
            :select     => @reflection.options[:select],
            :order      => @reflection.options[:order], 
            :include    => @reflection.options[:include],
            :readonly   => @reflection.options[:readonly]
          )
        end

        def construct_sql
          case
            when @reflection.options[:as]
              @finder_sql = 
                "#{@reflection.quoted_table_name}.#{@reflection.options[:as]}_id = #{@owner.quoted_id} AND " +
                "#{@reflection.quoted_table_name}.#{@reflection.options[:as]}_type = #{@owner.class.quote_value(@owner.class.base_class.name.to_s)}"
            else
              @finder_sql = "#{@reflection.quoted_table_name}.#{@reflection.primary_key_name} = #{@owner.quoted_id}"
          end
          @finder_sql << " AND (#{conditions})" if conditions
        end
        
        def construct_scope
          create_scoping = {}
          set_belongs_to_association_for(create_scoping)
          { :create => create_scoping }
        end

        def new_record(replace_existing)
          # Make sure we load the target first, if we plan on replacing the existing
          # instance. Otherwise, if the target has not previously been loaded
          # elsewhere, the instance we create will get orphaned.
          load_target if replace_existing
          record = @reflection.klass.send(:with_scope, :create => construct_scope[:create]) { yield @reflection.klass }

          if replace_existing
            replace(record, true) 
          else
            record[@reflection.primary_key_name] = @owner.id unless @owner.new_record?
            self.target = record
          end

          record
        end
    end
  end
end
