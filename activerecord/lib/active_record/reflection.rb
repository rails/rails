module ActiveRecord
  module Reflection # :nodoc:
    def self.included(base)
      base.extend(ClassMethods)
    end

    # Reflection allows you to interrogate Active Record classes and objects about their associations and aggregations.
    # This information can, for example, be used in a form builder that took an Active Record object and created input
    # fields for all of the attributes depending on their type and displayed the associations to other objects.
    #
    # You can find the interface for the AggregateReflection and AssociationReflection classes in the abstract MacroReflection class.
    module ClassMethods
      def create_reflection(macro, name, options, active_record)
        case macro
          when :has_many, :belongs_to, :has_one, :has_and_belongs_to_many
            reflection = AssociationReflection.new(macro, name, options, active_record)
          when :composed_of
            reflection = AggregateReflection.new(macro, name, options, active_record)
        end
        write_inheritable_hash :reflections, name => reflection
        reflection
      end
      
      def reflections
        read_inheritable_attribute(:reflections) or write_inheritable_attribute(:reflections, {})
      end
      
      # Returns an array of AggregateReflection objects for all the aggregations in the class.
      def reflect_on_all_aggregations
        reflections.values.select { |reflection| reflection.is_a?(AggregateReflection) }
      end

      # Returns the AggregateReflection object for the named +aggregation+ (use the symbol). Example:
      #   Account.reflect_on_aggregation(:balance) # returns the balance AggregateReflection
      def reflect_on_aggregation(aggregation)
        reflections[aggregation].is_a?(AggregateReflection) ? reflections[aggregation] : nil
      end

      # Returns an array of AssociationReflection objects for all the aggregations in the class. If you only want to reflect on a
      # certain association type, pass in the symbol for that as the first parameter.
      def reflect_on_all_associations(macro = nil)
        association_reflections = reflections.values.select { |reflection| reflection.is_a?(AssociationReflection) }
        macro ? association_reflections.select { |reflection| reflection.macro == macro } : association_reflections
      end

      # Returns the AssociationReflection object for the named +aggregation+ (use the symbol). Example:
      #   Account.reflect_on_association(:owner) # returns the owner AssociationReflection
      def reflect_on_association(association)
        reflections[association].is_a?(AssociationReflection) ? reflections[association] : nil
      end
    end


    # Abstract base class for AggregateReflection and AssociationReflection that describes the interface available for both of
    # those classes. Objects of AggregateReflection and AssociationReflection are returned by the Reflection::ClassMethods.
    class MacroReflection
      attr_reader :active_record
      def initialize(macro, name, options, active_record)
        @macro, @name, @options, @active_record = macro, name, options, active_record
      end

      # Returns the name of the macro, so it would return :balance for "composed_of :balance, :class_name => 'Money'" or
      # :clients for "has_many :clients".
      def name
        @name
      end

      # Returns the name of the macro, so it would return :composed_of for
      # "composed_of :balance, :class_name => 'Money'" or :has_many for "has_many :clients".
      def macro
        @macro
      end

      # Returns the hash of options used for the macro, so it would return { :class_name => "Money" } for
      # "composed_of :balance, :class_name => 'Money'" or {} for "has_many :clients".
      def options
        @options
      end

      # Returns the class for the macro, so "composed_of :balance, :class_name => 'Money'" would return the Money class and
      # "has_many :clients" would return the Client class.
      def klass() end
        
      def class_name
        @class_name ||= name_to_class_name(name.id2name)
      end

      def require_class
        require_association(class_name.underscore) if class_name
      end

      def ==(other_aggregation)
        name == other_aggregation.name && other_aggregation.options && active_record == other_aggregation.active_record
      end
    end


    # Holds all the meta-data about an aggregation as it was specified in the Active Record class.
    class AggregateReflection < MacroReflection #:nodoc:
      def klass
        @klass ||= Object.const_get(class_name)
      end

      private
        def name_to_class_name(name)
          name.capitalize.gsub(/_(.)/) { |s| $1.capitalize }
        end
    end

    # Holds all the meta-data about an association as it was specified in the Active Record class.
    class AssociationReflection < MacroReflection #:nodoc:
      def klass
        @klass ||= active_record.send(:compute_type, class_name)
      end

      def table_name
        @table_name ||= klass.table_name
      end

      def primary_key_name
        return @primary_key_name if @primary_key_name
        
        case macro
          when :belongs_to
            @primary_key_name = options[:foreign_key] || class_name.foreign_key
          else
            @primary_key_name = options[:foreign_key] || active_record.name.foreign_key
        end
      end
      
      def association_foreign_key
        @association_foreign_key ||= @options[:association_foreign_key] || class_name.foreign_key
      end

      private
        def name_to_class_name(name)
          if name =~ /::/
            name
          else
            if options[:class_name]
              options[:class_name]
            else
              class_name = name.to_s.camelize
              class_name = class_name.singularize if [ :has_many, :has_and_belongs_to_many ].include?(macro)
              class_name
            end
          end
        end
    end
  end
end
