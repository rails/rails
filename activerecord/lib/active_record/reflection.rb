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
            klass = options[:through] ? ThroughReflection : AssociationReflection
            reflection = klass.new(macro, name, options, active_record)
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

      # Returns an array of AssociationReflection objects for all the associations in the class. If you only want to reflect on a
      # certain association type, pass in the symbol (<tt>:has_many</tt>, <tt>:has_one</tt>, <tt>:belongs_to</tt>) for that as the first parameter.
      # Example:
      #
      #   Account.reflect_on_all_associations             # returns an array of all associations
      #   Account.reflect_on_all_associations(:has_many)  # returns an array of all has_many associations
      #
      def reflect_on_all_associations(macro = nil)
        association_reflections = reflections.values.select { |reflection| reflection.is_a?(AssociationReflection) }
        macro ? association_reflections.select { |reflection| reflection.macro == macro } : association_reflections
      end

      # Returns the AssociationReflection object for the named +association+ (use the symbol). Example:
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

      # Returns the name of the macro.  For example, <tt>composed_of :balance, :class_name => 'Money'</tt> will return
      # <tt>:balance</tt> or for <tt>has_many :clients</tt> it will return <tt>:clients</tt>.
      def name
        @name
      end

      # Returns the macro type. For example, <tt>composed_of :balance, :class_name => 'Money'</tt> will return <tt>:composed_of</tt>
      # or for <tt>has_many :clients</tt> will return <tt>:has_many</tt>.
      def macro
        @macro
      end

      # Returns the hash of options used for the macro.  For example, it would return <tt>{ :class_name => "Money" }</tt> for
      # <tt>composed_of :balance, :class_name => 'Money'</tt> or +{}+ for <tt>has_many :clients</tt>.
      def options
        @options
      end

      # Returns the class for the macro.  For example, <tt>composed_of :balance, :class_name => 'Money'</tt> returns the Money
      # class and <tt>has_many :clients</tt> returns the Client class.
      def klass
        @klass ||= class_name.constantize
      end

      # Returns the class name for the macro.  For example, <tt>composed_of :balance, :class_name => 'Money'</tt> returns <tt>'Money'</tt>
      # and <tt>has_many :clients</tt> returns <tt>'Client'</tt>.
      def class_name
        @class_name ||= options[:class_name] || derive_class_name
      end

      # Returns +true+ if +self+ and +other_aggregation+ have the same +name+ attribute, +active_record+ attribute,
      # and +other_aggregation+ has an options hash assigned to it.
      def ==(other_aggregation)
        other_aggregation.kind_of?(self.class) && name == other_aggregation.name && other_aggregation.options && active_record == other_aggregation.active_record
      end

      def sanitized_conditions #:nodoc:
        @sanitized_conditions ||= klass.send(:sanitize_sql, options[:conditions]) if options[:conditions]
      end

      # Returns +true+ if +self+ is a +belongs_to+ reflection.
      def belongs_to?
        macro == :belongs_to
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
      # Returns the target association's class:
      #
      #   class Author < ActiveRecord::Base
      #     has_many :books
      #   end
      #
      #   Author.reflect_on_association(:books).klass
      #   # => Book
      #
      # <b>Note:</b> do not call +klass.new+ or +klass.create+ to instantiate
      # a new association object. Use +build_association+ or +create_association+
      # instead. This allows plugins to hook into association object creation.
      def klass
        @klass ||= active_record.send(:compute_type, class_name)
      end

      # Returns a new, unsaved instance of the associated class. +options+ will
      # be passed to the class's constructor.
      def build_association(*options)
        klass.new(*options)
      end

      # Creates a new instance of the associated class, and immediates saves it
      # with ActiveRecord::Base#save. +options+ will be passed to the class's
      # creation method. Returns the newly created object.
      def create_association(*options)
        klass.create(*options)
      end

      # Creates a new instance of the associated class, and immediates saves it
      # with ActiveRecord::Base#save!. +options+ will be passed to the class's
      # creation method. If the created record doesn't pass validations, then an
      # exception will be raised.
      #
      # Returns the newly created object.
      def create_association!(*options)
        klass.create!(*options)
      end

      def table_name
        @table_name ||= klass.table_name
      end

      def quoted_table_name
        @quoted_table_name ||= klass.quoted_table_name
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

      def check_validity!
      end

      def through_reflection
        false
      end

      def through_reflection_primary_key_name
      end

      def source_reflection
        nil
      end

      private
        def derive_class_name
          class_name = name.to_s.camelize
          class_name = class_name.singularize if [ :has_many, :has_and_belongs_to_many ].include?(macro)
          class_name
        end

        def derive_primary_key_name
          if belongs_to?
            "#{name}_id"
          elsif options[:as]
            "#{options[:as]}_id"
          else
            active_record.name.foreign_key
          end
        end
    end

    # Holds all the meta-data about a :through association as it was specified in the Active Record class.
    class ThroughReflection < AssociationReflection #:nodoc:
      # Gets the source of the through reflection.  It checks both a singularized and pluralized form for <tt>:belongs_to</tt> or <tt>:has_many</tt>.
      # (The <tt>:tags</tt> association on Tagging below.)
      #
      #   class Post < ActiveRecord::Base
      #     has_many :taggings
      #     has_many :tags, :through => :taggings
      #   end
      #
      def source_reflection
        @source_reflection ||= source_reflection_names.collect { |name| through_reflection.klass.reflect_on_association(name) }.compact.first
      end

      # Returns the AssociationReflection object specified in the <tt>:through</tt> option
      # of a HasManyThrough or HasOneThrough association. Example:
      #
      #   class Post < ActiveRecord::Base
      #     has_many :taggings
      #     has_many :tags, :through => :taggings
      #   end
      #
      #   tags_reflection = Post.reflect_on_association(:tags)
      #   taggings_reflection = tags_reflection.through_reflection
      #
      def through_reflection
        @through_reflection ||= active_record.reflect_on_association(options[:through])
      end

      # Gets an array of possible <tt>:through</tt> source reflection names:
      #
      #   [:singularized, :pluralized]
      #
      def source_reflection_names
        @source_reflection_names ||= (options[:source] ? [options[:source]] : [name.to_s.singularize, name]).collect { |n| n.to_sym }
      end

      def check_validity!
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

      def through_reflection_primary_key
        through_reflection.belongs_to? ? through_reflection.klass.primary_key : through_reflection.primary_key_name
      end

      def through_reflection_primary_key_name
        through_reflection.primary_key_name if through_reflection.belongs_to?
      end

      private
        def derive_class_name
          # get the class_name of the belongs_to association of the through reflection
          options[:source_type] || source_reflection.class_name
        end
    end
  end
end
