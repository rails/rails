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
      
      # Returns a hash containing all AssociationReflection objects for the current class
      # Example:
      #
      #   Invoice.reflections
      #   Account.reflections
      #
      def reflections
        read_inheritable_attribute(:reflections) || write_inheritable_attribute(:reflections, {})
      end
       
      # Returns an array of AggregateReflection objects for all the aggregations in the class.
      def reflect_on_all_aggregations
        reflections.values.select { |reflection| reflection.is_a?(AggregateReflection) }
      end

      # Returns the AggregateReflection object for the named +aggregation+ (use the symbol). Example:
      #
      #   Account.reflect_on_aggregation(:balance) # returns the balance AggregateReflection
      #
      def reflect_on_aggregation(aggregation)
        reflections[aggregation].is_a?(AggregateReflection) ? reflections[aggregation] : nil
      end

      # Returns an array of AssociationReflection objects for all the aggregations in the class. If you only want to reflect on a
      # certain association type, pass in the symbol (:has_many, :has_one, :belongs_to) for that as the first parameter. 
      # Example:
      #
      #   Account.reflect_on_all_associations             # returns an array of all associations
      #   Account.reflect_on_all_associations(:has_many)  # returns an array of all has_many associations
      #
      def reflect_on_all_associations(macro = nil)
        association_reflections = reflections.values.select { |reflection| reflection.is_a?(AssociationReflection) }
        macro ? association_reflections.select { |reflection| reflection.macro == macro } : association_reflections
      end

      # Returns the AssociationReflection object for the named +aggregation+ (use the symbol). Example:
      #
      #   Account.reflect_on_association(:owner) # returns the owner AssociationReflection
      #   Invoice.reflect_on_association(:line_items).macro  # returns :has_many
      #
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

      # Returns the class for the macro, so "composed_of :balance, :class_name => 'Money'" returns the Money class and
      # "has_many :clients" returns the Client class.
      def klass
        @klass ||= class_name.constantize
      end

      def class_name
        @class_name ||= options[:class_name] || derive_class_name
      end

      def ==(other_aggregation)
        name == other_aggregation.name && other_aggregation.options && active_record == other_aggregation.active_record
      end

      private
        def derive_class_name
          name.to_s.camelize
        end
    end


    # Holds all the meta-data about an aggregation as it was specified in the Active Record class.
    class AggregateReflection < MacroReflection #:nodoc:
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
        @primary_key_name ||= options[:foreign_key] || derive_primary_key_name
      end

      def association_foreign_key
        @association_foreign_key ||= @options[:association_foreign_key] || class_name.foreign_key
      end

      def counter_cache_column
        if options[:counter_cache] == true
          "#{active_record.name.underscore.pluralize}_count"
        elsif options[:counter_cache]
          options[:counter_cache]
        end
      end

      def through_reflection
        @through_reflection ||= options[:through] ? active_record.reflect_on_association(options[:through]) : false
      end

      # Gets an array of possible :through source reflection names
      #
      #   [singularized, pluralized]
      #
      def source_reflection_names
        @source_reflection_names ||= (options[:source] ? [options[:source]] : [name.to_s.singularize, name]).collect { |n| n.to_sym }
      end

      # Gets the source of the through reflection.  It checks both a singularized and pluralized form for :belongs_to or :has_many.
      # (The :tags association on Tagging below)
      # 
      #   class Post
      #     has_many :tags, :through => :taggings
      #   end
      #
      def source_reflection
        return nil unless through_reflection
        @source_reflection ||= source_reflection_names.collect { |name| through_reflection.klass.reflect_on_association(name) }.compact.first
      end

      def check_validity!
        if options[:through]
          if through_reflection.nil?
            raise HasManyThroughAssociationNotFoundError.new(active_record.name, self)
          end
          
          if source_reflection.nil?
            raise HasManyThroughSourceAssociationNotFoundError.new(self)
          end

          if options[:source_type] && source_reflection.options[:polymorphic].nil?
            raise HasManyThroughAssociationPointlessSourceTypeError.new(active_record.name, self, source_reflection)
          end
          
          if source_reflection.options[:polymorphic] && options[:source_type].nil?
            raise HasManyThroughAssociationPolymorphicError.new(active_record.name, self, source_reflection)
          end
          
          unless [:belongs_to, :has_many].include?(source_reflection.macro) && source_reflection.options[:through].nil?
            raise HasManyThroughSourceAssociationMacroError.new(self)
          end
        end
      end

      private
        def derive_class_name
          # get the class_name of the belongs_to association of the through reflection
          if through_reflection
            options[:source_type] || source_reflection.class_name
          else
            class_name = name.to_s.camelize
            class_name = class_name.singularize if [ :has_many, :has_and_belongs_to_many ].include?(macro)
            class_name
          end
        end

        def derive_primary_key_name
          if macro == :belongs_to
            class_name.foreign_key
          elsif options[:as]
            "#{options[:as]}_id"
          else
            active_record.name.foreign_key
          end
        end
    end
  end
end
