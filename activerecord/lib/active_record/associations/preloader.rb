module ActiveRecord
  module Associations
    # Implements the details of eager loading of Active Record associations.
    #
    # Note that 'eager loading' and 'preloading' are actually the same thing.
    # However, there are two different eager loading strategies.
    #
    # The first one is by using table joins. This was only strategy available
    # prior to Rails 2.1. Suppose that you have an Author model with columns
    # 'name' and 'age', and a Book model with columns 'name' and 'sales'. Using
    # this strategy, Active Record would try to retrieve all data for an author
    # and all of its books via a single query:
    #
    #   SELECT * FROM authors
    #   LEFT OUTER JOIN books ON authors.id = books.author_id
    #   WHERE authors.name = 'Ken Akamatsu'
    #
    # However, this could result in many rows that contain redundant data. After
    # having received the first row, we already have enough data to instantiate
    # the Author object. In all subsequent rows, only the data for the joined
    # 'books' table is useful; the joined 'authors' data is just redundant, and
    # processing this redundant data takes memory and CPU time. The problem
    # quickly becomes worse and worse as the level of eager loading increases
    # (i.e. if Active Record is to eager load the associations' associations as
    # well).
    #
    # The second strategy is to use multiple database queries, one for each
    # level of association. Since Rails 2.1, this is the default strategy. In
    # situations where a table join is necessary (e.g. when the +:conditions+
    # option references an association's column), it will fallback to the table
    # join strategy.
    class Preloader #:nodoc:
      extend ActiveSupport::Autoload

      eager_autoload do
        autoload :Association,           'active_record/associations/preloader/association'
        autoload :SingularAssociation,   'active_record/associations/preloader/singular_association'
        autoload :CollectionAssociation, 'active_record/associations/preloader/collection_association'
        autoload :ThroughAssociation,    'active_record/associations/preloader/through_association'

        autoload :HasMany,             'active_record/associations/preloader/has_many'
        autoload :HasManyThrough,      'active_record/associations/preloader/has_many_through'
        autoload :HasOne,              'active_record/associations/preloader/has_one'
        autoload :HasOneThrough,       'active_record/associations/preloader/has_one_through'
        autoload :BelongsTo,           'active_record/associations/preloader/belongs_to'
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

      NULL_RELATION = Struct.new(:values).new({})

      def preload(records, associations, preload_scope = nil)
        records       = Array.wrap(records).compact.uniq
        associations  = Array.wrap(associations)
        preload_scope = preload_scope || NULL_RELATION

        if records.empty?
          []
        else
          associations.flat_map { |association|
            preloaders_on association, records, preload_scope
          }
        end
      end

      private

      def preloaders_on(association, records, scope)
        case association
        when Hash
          preloaders_for_hash(association, records, scope)
        when Symbol
          preloaders_for_one(association, records, scope)
        when String
          preloaders_for_one(association.to_sym, records, scope)
        else
          raise ArgumentError, "#{association.inspect} was not recognised for preload"
        end
      end

      def preloaders_for_hash(association, records, scope)
        association.flat_map { |parent, child|
          loaders = preloaders_for_one parent, records, scope

          recs = loaders.flat_map(&:preloaded_records).uniq
          loaders.concat Array.wrap(child).flat_map { |assoc|
            preloaders_on assoc, recs, scope
          }
          loaders
        }
      end

      # Not all records have the same class, so group then preload group on the reflection
      # itself so that if various subclass share the same association then we do not split
      # them unnecessarily
      #
      # Additionally, polymorphic belongs_to associations can have multiple associated
      # classes, depending on the polymorphic_type field. So we group by the classes as
      # well.
      def preloaders_for_one(association, records, scope)
        grouped_records(association, records).flat_map do |reflection, klasses|
          klasses.map do |rhs_klass, rs|
            loader = preloader_for(reflection, rs, rhs_klass).new(rhs_klass, rs, reflection, scope)
            loader.run self
            loader
          end
        end
      end

      def grouped_records(association, records)
        h = {}
        records.each do |record|
          next unless record
          assoc = record.association(association)
          klasses = h[assoc.reflection] ||= {}
          (klasses[assoc.klass] ||= []) << record
        end
        h
      end

      class AlreadyLoaded
        attr_reader :owners, :reflection

        def initialize(klass, owners, reflection, preload_scope)
          @owners = owners
          @reflection = reflection
        end

        def run(preloader); end

        def preloaded_records
          owners.flat_map { |owner| owner.association(reflection.name).target }
        end
      end

      class NullPreloader
        def self.new(klass, owners, reflection, preload_scope); self; end
        def self.run(preloader); end
      end

      def preloader_for(reflection, owners, rhs_klass)
        return NullPreloader unless rhs_klass

        if owners.first.association(reflection.name).loaded?
          return AlreadyLoaded
        end

        case reflection.macro
        when :has_many
          reflection.options[:through] ? HasManyThrough : HasMany
        when :has_one
          reflection.options[:through] ? HasOneThrough : HasOne
        when :belongs_to
          BelongsTo
        end
      end
    end
  end
end
