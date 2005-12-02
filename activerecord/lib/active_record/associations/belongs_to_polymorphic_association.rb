module ActiveRecord
  module Associations
    class BelongsToPolymorphicAssociation < BelongsToAssociation #:nodoc:
      def initialize(owner, association_name, association_class_name, association_class_primary_key_name, options)
        @owner = owner
        @options = options
        @association_name = association_name
        @association_class_primary_key_name = association_class_primary_key_name

        proxy_extend(options[:extend]) if options[:extend]

        reset
      end
      
      def create(attributes = {})
        raise ActiveRecord::ActiveRecordError, "Can't create an abstract polymorphic object"
      end

      def build(attributes = {})
        raise ActiveRecord::ActiveRecordError, "Can't build an abstract polymorphic object"
      end

      def replace(obj, dont_save = false)
        if obj.nil?
          @target = @owner[@association_class_primary_key_name] = @owner[@options[:foreign_type]] = nil
        else
          @target = (AssociationProxy === obj ? obj.target : obj)

          unless obj.new_record?
            @owner[@association_class_primary_key_name] = obj.id
            @owner[@options[:foreign_type]] = ActiveRecord::Base.send(:class_name_of_active_record_descendant, obj.class).to_s
          end

          @updated = true
        end

        @loaded = true

        return (@target.nil? ? nil : self)
      end
      
      private
        def find_target
          return nil if association_class.nil?

          if @options[:conditions]
            association_class.find(
              @owner[@association_class_primary_key_name], 
              :conditions => interpolate_sql(@options[:conditions]),
              :include    => @options[:include]
            )
          else
            association_class.find(@owner[@association_class_primary_key_name], :include => @options[:include])
          end
        end

        def foreign_key_present
          !@owner[@association_class_primary_key_name].nil?
        end

        def target_obsolete?
          @owner[@association_class_primary_key_name] != @target.id
        end
        
        def association_class
          @owner[@options[:foreign_type]] ? @owner[@options[:foreign_type]].constantize : nil
        end
    end
  end
end
