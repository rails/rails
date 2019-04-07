# frozen_string_literal: true

module ActiveRecord
  module Associations
    # Implements the details of eager loading of Active Record associations.
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
    # multiple queries like this:
    #
    #   Author.includes(:books).where(name: ['bell hooks', 'Homer']).to_a
    #
    #   => SELECT `authors`.* FROM `authors` WHERE `name` IN ('bell hooks', 'Homer')
    #   => SELECT `books`.* FROM `books` WHERE `author_id` IN (2, 5)
    #
    # Active Record saves the ids of the records from the first query to use in
    # the second. Depending on the number of associations involved there can be
    # arbitrarily many SQL queries made.
    #
    # However, if there is a WHERE clause that spans across tables Active
    # Record will fall back to a slightly more resource-intensive single query:
    #
    #   Author.includes(:books).where(books: {title: 'Illiad'}).to_a
    #   => SELECT `authors`.`id` AS t0_r0, `authors`.`name` AS t0_r1, `authors`.`age` AS t0_r2,
    #             `books`.`id`   AS t1_r0, `books`.`title`  AS t1_r1, `books`.`sales` AS t1_r2
    #      FROM `authors`
    #      LEFT OUTER JOIN `books` ON `authors`.`id` =  `books`.`author_id`
    #      WHERE `books`.`title` = 'Illiad'
    #
    # This could result in many rows that contain redundant data and it performs poorly at scale
    # and is therefore only used when necessary.
    #
    class Preloader #:nodoc:
      extend ActiveSupport::Autoload

      eager_autoload do
        autoload :Association,        "active_record/associations/preloader/association"
        autoload :ThroughAssociation, "active_record/associations/preloader/through_association"
      end

      # Eager loads the named associations for the given Active Record record(s).
      #
      # In this description, 'association name' shall refer to the name passed
      # to an association creation method. For example, a model that specifies
      # <tt>belongs_to :author</tt>, <tt>has_many :buyers</tt> has association
      # names +:author+ and +:buyers+.
      #
      # == Parameters
      # +records+ is an array of ActiveRecord::Base. This array needs not be flat,
      # i.e. +records+ itself may also contain arrays of records. In any case,
      # +preload_associations+ will preload the all associations records by
      # flattening +records+.
      #
      # +associations+ specifies one or more associations that you want to
      # preload. It may be:
      # - a Symbol or a String which specifies a single association name. For
      #   example, specifying +:books+ allows this method to preload all books
      #   for an Author.
      # - an Array which specifies multiple association names. This array
      #   is processed recursively. For example, specifying <tt>[:avatar, :books]</tt>
      #   allows this method to preload an author's avatar as well as all of his
      #   books.
      # - a Hash which specifies multiple association names, as well as
      #   association names for the to-be-preloaded association objects. For
      #   example, specifying <tt>{ author: :avatar }</tt> will preload a
      #   book's author, as well as that author's avatar.
      #
      # +:associations+ has the same format as the +:include+ option for
      # <tt>ActiveRecord::Base.find</tt>. So +associations+ could look like this:
      #
      #   :books
      #   [ :books, :author ]
      #   { author: :avatar }
      #   [ :books, { author: :avatar } ]
      def preload(records, associations, preload_scope = nil)
        records = Array.wrap(records).compact

        if records.empty?
          []
        else
          Array.wrap(associations).flat_map { |association|
            preloaders_on association, records, preload_scope
          }
        end
      end

      private

        # Loads all the given data into +records+ for the +association+.
        def preloaders_on(association, records, scope, polymorphic_parent = false)
          case association
          when Hash
            preloaders_for_hash(association, records, scope, polymorphic_parent)
          when Symbol, String
            preloaders_for_one(association, records, scope, polymorphic_parent)
          else
            raise ArgumentError, "#{association.inspect} was not recognized for preload"
          end
        end

        def preloaders_for_hash(association, records, scope, polymorphic_parent)
          association.flat_map { |parent, child|
            grouped_records(parent, records, polymorphic_parent).flat_map do |reflection, reflection_records|
              loaders = preloaders_for_reflection(reflection, reflection_records, scope)
              recs = loaders.flat_map(&:preloaded_records)
              child_polymorphic_parent = reflection && reflection.options[:polymorphic]
              loaders.concat Array.wrap(child).flat_map { |assoc|
                preloaders_on assoc, recs, scope, child_polymorphic_parent
              }
              loaders
            end
          }
        end

        # Loads all the given data into +records+ for a singular +association+.
        #
        # Functions by instantiating a preloader class such as Preloader::Association and
        # call the +run+ method for each passed in class in the +records+ argument.
        #
        # Not all records have the same class, so group then preload group on the reflection
        # itself so that if various subclass share the same association then we do not split
        # them unnecessarily
        #
        # Additionally, polymorphic belongs_to associations can have multiple associated
        # classes, depending on the polymorphic_type field. So we group by the classes as
        # well.
        def preloaders_for_one(association, records, scope, polymorphic_parent)
          grouped_records(association, records, polymorphic_parent)
            .flat_map do |reflection, reflection_records|
              preloaders_for_reflection reflection, reflection_records, scope
            end
        end

        def preloaders_for_reflection(reflection, records, scope)
          records.group_by { |record| record.association(reflection.name).klass }.map do |rhs_klass, rs|
            preloader_for(reflection, rs).new(rhs_klass, rs, reflection, scope).run
          end
        end

        def grouped_records(association, records, polymorphic_parent)
          h = {}
          records.each do |record|
            reflection = record.class._reflect_on_association(association)
            next if polymorphic_parent && !reflection || !record.association(association).klass
            (h[reflection] ||= []) << record
          end
          h
        end

        class AlreadyLoaded # :nodoc:
          def initialize(klass, owners, reflection, preload_scope)
            @owners = owners
            @reflection = reflection
          end

          def run
            self
          end

          def preloaded_records
            @preloaded_records ||= records_by_owner.flat_map(&:last)
          end

          def records_by_owner
            @records_by_owner ||= owners.each_with_object({}) do |owner, result|
              result[owner] = Array(owner.association(reflection.name).target)
            end
          end

          private
            attr_reader :owners, :reflection
        end

        # Returns a class containing the logic needed to load preload the data
        # and attach it to a relation. The class returned implements a `run` method
        # that accepts a preloader.
        def preloader_for(reflection, owners)
          if owners.first.association(reflection.name).loaded?
            return AlreadyLoaded
          end
          reflection.check_preloadable!

          if reflection.options[:through]
            ThroughAssociation
          else
            Association
          end
        end
    end
  end
end
