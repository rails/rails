# frozen_string_literal: true

module ActiveRecord
  module Associations
    class LazyPreloader
      # Implements the details of lazy eager loading of Active Record associations.
      #
      # Suppose that you have the following two Active Record models:
      #
      #   class Author < ActiveRecord::Base
      #     # columns: name, age
      #     has_many :books
      #   end
      #
      #   class Book < ActiveRecord::Base
      #     # columns: title, sales, author_id
      #   end
      #
      # When you load an author with all associated books Active Record will make
      # only one query:
      #
      #   authors = Author.lazy_preload(:books).where(name: ['bell hooks', 'Homer']).to_a
      #
      #   => SELECT `authors`.* FROM `authors` WHERE `name` IN ('bell hooks', 'Homer')
      #
      # Then you probably will want to retrieve books while iterating authors
      #
      #   authors.each { |author| read author.books }
      #
      # And only after books method invocation second query will be executed
      # to load all books for authors in the collection:
      #
      # => SELECT `books`.* FROM `books` WHERE `author_id` IN (2, 5)
      #
      require "weakref"

      class Registry
        def self.store(record, instance)
          record.instance_variable_set :@_lazy_preloader, instance
        end

        def self.fetch(record)
          if record.instance_variable_defined? :@_lazy_preloader
            yield record.instance_variable_get :@_lazy_preloader
          end
        end
      end

      def self.preload(records, preloader, associations, polymorphic_parent: false, loaded_associations: true)
        new(records, preloader, associations, polymorphic_parent, loaded_associations).tap do |lazy_loader|
          records.each { |record| LazyPreloader::Registry.store record, lazy_loader }
        end
      end

      private_class_method :new

      def initialize(records, preloader, associations, polymorphic_parent, loaded_associations)
        @records = weak_references records
        @preloader = preloader
        @associations = normalize_associations associations
        @polymorphic_parent = polymorphic_parent

        check_preloadable! records
        preload_association_on_loaded_record(records, loaded_associations)
      end

      # Maps weak references to real objects
      def records
        @records.values.map!(&:__getobj__)
      end

      # Determines whether lazy loading of the given association is needed
      def should_load?(association)
        associations_to_load.include? association
      end

      # Preloads the given association and plans to lazily preload nested associations
      def preload(association)
        return unless should_load? association
        associations_to_load.delete association

        @preloader.preload records, association, nil, @polymorphic_parent
        load_next_records association
      end

      private
        def check_preloadable!(records)
          records.uniq(&:class).each do |record|
            associations_to_load.each do |association|
              if reflection = record.class._reflect_on_association(association)
                reflection.check_preloadable!
              elsif !@polymorphic_parent
                record.association(association)
              end
            end
          end
        end

        def weak_references(records)
          record_finalizer = ->(object_id) { @records.delete object_id }

          records.index_by(&:object_id).transform_values! do |record|
            ::ObjectSpace.define_finalizer record, record_finalizer
            ::WeakRef.new record
          end
        end

        def load_next_records(parent_association, loaded_associations = false)
          child_association = associations_to_load_next(parent_association)
          return if child_association.empty?

          loaded_records = []
          child_polymorphic_parent = false
          records.each do |record|
            if reflection = record.class._reflect_on_association(parent_association)
              loaded_records.push(*record.association(parent_association).target)
              child_polymorphic_parent ||= reflection.options[:polymorphic]
            end
          end

          @preloader.lazy_preload loaded_records, child_association, polymorphic_parent: child_polymorphic_parent, loaded_associations: loaded_associations
        end

        def preload_association_on_loaded_record(records, loaded_associations)
          return unless loaded_associations

          associations_to_check = @associations.each_with_object([]) do |association, result|
            result.push(*association.keys) if association.is_a?(Hash)
          end
          associations_to_check.uniq!

          if loaded_associations != true
            loaded_associations = normalize_associations(loaded_associations)
            associations_to_check &= root_associations(loaded_associations)
          end

          return if associations_to_check.empty?

          records.each do |record|
            associations_to_check.reject! do |association|
              if record.class._reflect_on_association(association) && record.association(association).loaded?
                child_loaded_associations = loaded_associations == true || child_associations(loaded_associations, association)
                load_next_records(association, child_loaded_associations)
                true
              else
                false
              end
            end

            return if associations_to_check.empty?
          end
        end

        def associations_to_load
          @associations_to_load ||= root_associations(@associations)
        end

        def associations_to_load_next(parent_association)
          @associations_to_load_next ||= {}

          @associations_to_load_next[parent_association] ||= child_associations(@associations, parent_association).freeze
        end

        def root_associations(associations)
          associations.flat_map do |association|
            association.is_a?(Hash) ? association.keys : association
          end.tap(&:uniq!)
        end

        def child_associations(associations, parent_association)
          associations.each_with_object([]) do |current, result|
            if current.is_a?(::Hash) && current.key?(parent_association)
              result << current[parent_association]
            end
          end
        end

        def normalize_associations(associations)
          Array.wrap(associations).flatten.map! do |association|
            case association
            when Hash
              association.transform_keys { |key| symbolize_association(key) }
            else
              symbolize_association(association)
            end
          end
        end

        def symbolize_association(association)
          case association
          when Symbol, String
            association.to_sym
          else
            raise ArgumentError, "#{association.inspect} was not recognized for preload"
          end
        end
    end
  end
end
