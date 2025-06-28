# frozen_string_literal: true

module ActiveRecord
  class AssociationNotFoundError < ConfigurationError # :nodoc:
    attr_reader :record, :association_name

    def initialize(record = nil, association_name = nil)
      @record           = record
      @association_name = association_name
      if record && association_name
        super("Association named '#{association_name}' was not found on #{record.class.name}; perhaps you misspelled it?")
      else
        super("Association was not found.")
      end
    end

    if defined?(DidYouMean::Correctable) && defined?(DidYouMean::SpellChecker)
      include DidYouMean::Correctable

      def corrections
        if record && association_name
          @corrections ||= begin
            maybe_these = record.class.reflections.keys
            DidYouMean::SpellChecker.new(dictionary: maybe_these).correct(association_name)
          end
        else
          []
        end
      end
    end
  end

  class InverseOfAssociationNotFoundError < ActiveRecordError # :nodoc:
    attr_reader :reflection, :associated_class

    def initialize(reflection = nil, associated_class = nil)
      if reflection
        @reflection = reflection
        @associated_class = associated_class.nil? ? reflection.klass : associated_class
        super("Could not find the inverse association for #{reflection.name} (#{reflection.options[:inverse_of].inspect} in #{associated_class.nil? ? reflection.class_name : associated_class.name})")
      else
        super("Could not find the inverse association.")
      end
    end

    if defined?(DidYouMean::Correctable) && defined?(DidYouMean::SpellChecker)
      include DidYouMean::Correctable

      def corrections
        if reflection && associated_class
          @corrections ||= begin
            maybe_these = associated_class.reflections.keys
            DidYouMean::SpellChecker.new(dictionary: maybe_these).correct(reflection.options[:inverse_of].to_s)
          end
        else
          []
        end
      end
    end
  end

  class InverseOfAssociationRecursiveError < ActiveRecordError # :nodoc:
    attr_reader :reflection
    def initialize(reflection = nil)
      if reflection
        @reflection = reflection
        super("Inverse association #{reflection.name} (#{reflection.options[:inverse_of].inspect} in #{reflection.class_name}) is recursive.")
      else
        super("Inverse association is recursive.")
      end
    end
  end

  class HasManyThroughAssociationNotFoundError < ActiveRecordError # :nodoc:
    attr_reader :owner_class, :reflection

    def initialize(owner_class = nil, reflection = nil)
      if owner_class && reflection
        @owner_class = owner_class
        @reflection = reflection
        super("Could not find the association #{reflection.options[:through].inspect} in model #{owner_class.name}")
      else
        super("Could not find the association.")
      end
    end

    if defined?(DidYouMean::Correctable) && defined?(DidYouMean::SpellChecker)
      include DidYouMean::Correctable

      def corrections
        if owner_class && reflection
          @corrections ||= begin
            maybe_these = owner_class.reflections.keys
            maybe_these -= [reflection.name.to_s] # remove failing reflection
            DidYouMean::SpellChecker.new(dictionary: maybe_these).correct(reflection.options[:through].to_s)
          end
        else
          []
        end
      end
    end
  end

  class HasManyThroughAssociationPolymorphicSourceError < ActiveRecordError # :nodoc:
    def initialize(owner_class_name = nil, reflection = nil, source_reflection = nil)
      if owner_class_name && reflection && source_reflection
        super("Cannot have a has_many :through association '#{owner_class_name}##{reflection.name}' on the polymorphic object '#{source_reflection.class_name}##{source_reflection.name}' without 'source_type'. Try adding 'source_type: \"#{reflection.name.to_s.classify}\"' to 'has_many :through' definition.")
      else
        super("Cannot have a has_many :through association.")
      end
    end
  end

  class HasManyThroughAssociationPolymorphicThroughError < ActiveRecordError # :nodoc:
    def initialize(owner_class_name = nil, reflection = nil)
      if owner_class_name && reflection
        super("Cannot have a has_many :through association '#{owner_class_name}##{reflection.name}' which goes through the polymorphic association '#{owner_class_name}##{reflection.through_reflection.name}'.")
      else
        super("Cannot have a has_many :through association.")
      end
    end
  end

  class HasManyThroughAssociationPointlessSourceTypeError < ActiveRecordError # :nodoc:
    def initialize(owner_class_name = nil, reflection = nil, source_reflection = nil)
      if owner_class_name && reflection && source_reflection
        super("Cannot have a has_many :through association '#{owner_class_name}##{reflection.name}' with a :source_type option if the '#{reflection.through_reflection.class_name}##{source_reflection.name}' is not polymorphic. Try removing :source_type on your association.")
      else
        super("Cannot have a has_many :through association.")
      end
    end
  end

  class HasOneThroughCantAssociateThroughCollection < ActiveRecordError # :nodoc:
    def initialize(owner_class_name = nil, reflection = nil, through_reflection = nil)
      if owner_class_name && reflection && through_reflection
        super("Cannot have a has_one :through association '#{owner_class_name}##{reflection.name}' where the :through association '#{owner_class_name}##{through_reflection.name}' is a collection. Specify a has_one or belongs_to association in the :through option instead.")
      else
        super("Cannot have a has_one :through association.")
      end
    end
  end

  class HasOneAssociationPolymorphicThroughError < ActiveRecordError # :nodoc:
    def initialize(owner_class_name = nil, reflection = nil)
      if owner_class_name && reflection
        super("Cannot have a has_one :through association '#{owner_class_name}##{reflection.name}' which goes through the polymorphic association '#{owner_class_name}##{reflection.through_reflection.name}'.")
      else
        super("Cannot have a has_one :through association.")
      end
    end
  end

  class HasManyThroughSourceAssociationNotFoundError < ActiveRecordError # :nodoc:
    def initialize(reflection = nil)
      if reflection
        through_reflection      = reflection.through_reflection
        source_reflection_names = reflection.source_reflection_names
        source_associations     = reflection.through_reflection.klass._reflections.keys
        super("Could not find the source association(s) #{source_reflection_names.collect(&:inspect).to_sentence(two_words_connector: ' or ', last_word_connector: ', or ')} in model #{through_reflection.klass}. Try 'has_many #{reflection.name.inspect}, :through => #{through_reflection.name.inspect}, :source => <name>'. Is it one of #{source_associations.to_sentence(two_words_connector: ' or ', last_word_connector: ', or ')}?")
      else
        super("Could not find the source association(s).")
      end
    end
  end

  class HasManyThroughOrderError < ActiveRecordError # :nodoc:
    def initialize(owner_class_name = nil, reflection = nil, through_reflection = nil)
      if owner_class_name && reflection && through_reflection
        super("Cannot have a has_many :through association '#{owner_class_name}##{reflection.name}' which goes through '#{owner_class_name}##{through_reflection.name}' before the through association is defined.")
      else
        super("Cannot have a has_many :through association before the through association is defined.")
      end
    end
  end

  class ThroughCantAssociateThroughHasOneOrManyReflection < ActiveRecordError # :nodoc:
    def initialize(owner = nil, reflection = nil)
      if owner && reflection
        super("Cannot modify association '#{owner.class.name}##{reflection.name}' because the source reflection class '#{reflection.source_reflection.class_name}' is associated to '#{reflection.through_reflection.class_name}' via :#{reflection.source_reflection.macro}.")
      else
        super("Cannot modify association.")
      end
    end
  end

  class CompositePrimaryKeyMismatchError < ActiveRecordError # :nodoc:
    attr_reader :reflection

    def initialize(reflection = nil)
      if reflection
        if reflection.has_one? || reflection.collection?
          super("Association #{reflection.active_record}##{reflection.name} primary key #{reflection.active_record_primary_key} doesn't match with foreign key #{reflection.foreign_key}. Please specify query_constraints, or primary_key and foreign_key values.")
        else
          super("Association #{reflection.active_record}##{reflection.name} primary key #{reflection.association_primary_key} doesn't match with foreign key #{reflection.foreign_key}. Please specify query_constraints, or primary_key and foreign_key values.")
        end
      else
        super("Association primary key doesn't match with foreign key.")
      end
    end
  end

  class AmbiguousSourceReflectionForThroughAssociation < ActiveRecordError # :nodoc:
    def initialize(klass, macro, association_name, options, possible_sources)
      example_options = options.dup
      example_options[:source] = possible_sources.first

      super("Ambiguous source reflection for through association. Please " \
            "specify a :source directive on your declaration like:\n" \
            "\n" \
            "  class #{klass} < ActiveRecord::Base\n" \
            "    #{macro} :#{association_name}, #{example_options}\n" \
            "  end"
           )
    end
  end

  class HasManyThroughCantAssociateThroughHasOneOrManyReflection < ThroughCantAssociateThroughHasOneOrManyReflection # :nodoc:
  end

  class HasOneThroughCantAssociateThroughHasOneOrManyReflection < ThroughCantAssociateThroughHasOneOrManyReflection # :nodoc:
  end

  class ThroughNestedAssociationsAreReadonly < ActiveRecordError # :nodoc:
    def initialize(owner = nil, reflection = nil)
      if owner && reflection
        super("Cannot modify association '#{owner.class.name}##{reflection.name}' because it goes through more than one other association.")
      else
        super("Through nested associations are read-only.")
      end
    end
  end

  class HasManyThroughNestedAssociationsAreReadonly < ThroughNestedAssociationsAreReadonly # :nodoc:
  end

  class HasOneThroughNestedAssociationsAreReadonly < ThroughNestedAssociationsAreReadonly # :nodoc:
  end

  # This error is raised when trying to eager load a polymorphic association using a JOIN.
  # Eager loading polymorphic associations is only possible with
  # {ActiveRecord::Relation#preload}[rdoc-ref:QueryMethods#preload].
  class EagerLoadPolymorphicError < ActiveRecordError
    def initialize(reflection = nil)
      if reflection
        super("Cannot eagerly load the polymorphic association #{reflection.name.inspect}")
      else
        super("Eager load polymorphic error.")
      end
    end
  end

  # This error is raised when trying to destroy a parent instance in N:1 or 1:1 associations
  # (has_many, has_one) when there is at least 1 child associated instance.
  # ex: if @project.tasks.size > 0, DeleteRestrictionError will be raised when trying to destroy @project
  class DeleteRestrictionError < ActiveRecordError # :nodoc:
    def initialize(name = nil)
      if name
        super("Cannot delete record because of dependent #{name}")
      else
        super("Delete restriction error.")
      end
    end
  end

  class DeprecatedAssociationError < ActiveRecordError
  end
end
