# frozen_string_literal: true

require "active_support/core_ext/enumerable"

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
    class Preloader #:nodoc:
      extend ActiveSupport::Autoload

      eager_autoload do
        autoload :Association,        "active_record/associations/preloader/association"
        autoload :ThroughAssociation, "active_record/associations/preloader/through_association"
      end

      attr_reader :records, :associations, :scope, :associate_by_default, :polymorphic_parent

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
      # +preload_associations+ will preload all associations records by
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
      def initialize(associate_by_default: true, polymorphic_parent: false, **kwargs)
        if kwargs.empty?
          ActiveSupport::Deprecation.warn("Calling `Preloader#initialize` without arguments is deprecated and will be removed in Rails 7.0.")
        else
          @records = kwargs[:records]
          @associations = kwargs[:associations]
          @scope = kwargs[:scope]
          @associate_by_default = associate_by_default
          @polymorphic_parent = polymorphic_parent
        end
      end

      def call
        return [] if associations.nil? || records.length.zero?

        build_preloaders
      end

      def preload(records, associations, preload_scope = nil)
        ActiveSupport::Deprecation.warn("`preload` is deprecated and will be removed in Rails 7.0. Call `Preloader.new(kwargs).call` instead.")

        Preloader.new(records: records, associations: associations, scope: preload_scope).call
      end

      private
        def build_preloaders
          Array.wrap(associations).flat_map { |association|
            Array(association).flat_map { |parent, child|
              grouped_records(parent).flat_map do |reflection, reflection_records|
                loaders = preloaders_for_reflection(reflection, reflection_records)

                if child
                  loaders.concat build_child_preloader(reflection, child, loaders)
                end

                loaders
              end
            }
          }
        end

        def build_child_preloader(reflection, child, loaders)
          child_polymorphic_parent = reflection && reflection.options[:polymorphic]
          preloaded_records = loaders.flat_map(&:preloaded_records).uniq

          Preloader.new(records: preloaded_records, associations: child, scope: scope, associate_by_default: associate_by_default, polymorphic_parent: child_polymorphic_parent).call
        end

        def preloaders_for_reflection(reflection, reflection_records)
          reflection_records.group_by { |record| record.association(reflection.name).klass }.map do |rhs_klass, rs|
            preloader_for(reflection).new(rhs_klass, rs, reflection, scope, associate_by_default).run
          end
        end

        def grouped_records(association)
          h = {}
          records.each do |record|
            reflection = record.class._reflect_on_association(association)
            next if polymorphic_parent && !reflection || !record.association(association).klass
            (h[reflection] ||= []) << record
          end
          h
        end

        # Returns a class containing the logic needed to load preload the data
        # and attach it to a relation. The class returned implements a `run` method
        # that accepts a preloader.
        def preloader_for(reflection)
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
