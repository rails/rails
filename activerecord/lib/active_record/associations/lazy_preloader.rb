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
      class WeakRegistry
        def self.set(record, instance)
          record.instance_variable_set :@_lazy_preloader, instance
        end

        def self.get(record)
          record.instance_variable_get :@_lazy_preloader
        end
      end

      def initialize(records, preloader, associations)
        @records = records
        @preloader = preloader
        @associations = associations
      end

      # Determines whether lazy loading of the given association is needed
      def should_load?(association)
        current_associations.include? association
      end

      # Preloads the given association and plans to lazily preload nested associations
      def preload(association)
        return unless should_load? association
        current_associations.delete association
        @preloader.preload @records, association
        @preloader.lazy_preload loaded_records(association), next_associations(association)
      end

      private

        def loaded_records(association)
          @records.flat_map { |record| record.send association }
        end

        def current_associations
          @current_associations ||= @associations
            .flatten
            .map { |association| association.is_a?(::Hash) ? association.keys : association }
            .flatten
        end

        def next_associations(association)
          @associations.flatten.each_with_object([]) do |current, result|
            if current.is_a?(::Hash) && current.key?(association)
              result << current[association]
            end
          end
        end
    end
  end
end
