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
    class Preloader # :nodoc:
      extend ActiveSupport::Autoload

      eager_autoload do
        autoload :Association,        "active_record/associations/preloader/association"
        autoload :Batch,              "active_record/associations/preloader/batch"
        autoload :Branch,             "active_record/associations/preloader/branch"
        autoload :ThroughAssociation, "active_record/associations/preloader/through_association"
      end

      attr_reader :records, :associations, :scope, :associate_by_default

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
      # +:associations+ has the same format as the +:include+ method in
      # <tt>ActiveRecord::QueryMethods</tt>. So +associations+ could look like this:
      #
      #   :books
      #   [ :books, :author ]
      #   { author: :avatar }
      #   [ :books, { author: :avatar } ]
      #
      # +available_records+ is an array of ActiveRecord::Base. The Preloader
      # will try to use the objects in this array to preload the requested
      # associations before querying the database. This can save database
      # queries by reusing in-memory objects. The optimization is only applied
      # to single associations (i.e. :belongs_to, :has_one) with no scopes.
      def initialize(associate_by_default: true, **kwargs)
        if kwargs.empty?
          ActiveSupport::Deprecation.warn("Calling `Preloader#initialize` without arguments is deprecated and will be removed in Rails 7.0.")
        else
          @records = kwargs[:records]
          @associations = kwargs[:associations]
          @scope = kwargs[:scope]
          @available_records = kwargs[:available_records] || []
          @associate_by_default = associate_by_default

          @tree = Branch.new(
            parent: nil,
            association: nil,
            children: associations,
            associate_by_default: @associate_by_default,
            scope: @scope
          )
          @tree.preloaded_records = records
        end
      end

      def empty?
        associations.nil? || records.length == 0
      end

      def call
        Batch.new([self], available_records: @available_records).call

        loaders
      end

      def preload(records, associations, preload_scope = nil)
        ActiveSupport::Deprecation.warn("`preload` is deprecated and will be removed in Rails 7.0. Call `Preloader.new(kwargs).call` instead.")

        Preloader.new(records: records, associations: associations, scope: preload_scope).call
      end

      def branches
        @tree.children
      end

      def loaders
        branches.flat_map(&:loaders)
      end
    end
  end
end
