module ActiveRecord
  # See ActiveRecord::AssociationPreload::ClassMethods for documentation.
  module AssociationPreload #:nodoc:
    extend ActiveSupport::Concern

    # Implements the details of eager loading of ActiveRecord associations.
    # Application developers should not use this module directly.
    #
    # ActiveRecord::Base is extended with this module. The source code in
    # ActiveRecord::Base references methods defined in this module.
    #
    # Note that 'eager loading' and 'preloading' are actually the same thing.
    # However, there are two different eager loading strategies.
    #
    # The first one is by using table joins. This was only strategy available
    # prior to Rails 2.1. Suppose that you have an Author model with columns
    # 'name' and 'age', and a Book model with columns 'name' and 'sales'. Using
    # this strategy, ActiveRecord would try to retrieve all data for an author
    # and all of its books via a single query:
    #
    #   SELECT * FROM authors
    #   LEFT OUTER JOIN books ON authors.id = books.id
    #   WHERE authors.name = 'Ken Akamatsu'
    #
    # However, this could result in many rows that contain redundant data. After
    # having received the first row, we already have enough data to instantiate
    # the Author object. In all subsequent rows, only the data for the joined
    # 'books' table is useful; the joined 'authors' data is just redundant, and
    # processing this redundant data takes memory and CPU time. The problem
    # quickly becomes worse and worse as the level of eager loading increases
    # (i.e. if ActiveRecord is to eager load the associations' associations as
    # well).
    #
    # The second strategy is to use multiple database queries, one for each
    # level of association. Since Rails 2.1, this is the default strategy. In
    # situations where a table join is necessary (e.g. when the +:conditions+
    # option references an association's column), it will fallback to the table
    # join strategy.
    #
    # See also ActiveRecord::Associations::ClassMethods, which explains eager
    # loading in a more high-level (application developer-friendly) manner.
    module ClassMethods
      protected

      # Eager loads the named associations for the given ActiveRecord record(s).
      #
      # In this description, 'association name' shall refer to the name passed
      # to an association creation method. For example, a model that specifies
      # <tt>belongs_to :author</tt>, <tt>has_many :buyers</tt> has association
      # names +:author+ and +:buyers+.
      #
      # == Parameters
      # +records+ is an array of ActiveRecord::Base. This array needs not be flat,
      # i.e. +records+ itself may also contain arrays of records. In any case,
      # +preload_associations+ will preload the associations all records by
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
      #   example, specifying <tt>{ :author => :avatar }</tt> will preload a
      #   book's author, as well as that author's avatar.
      #
      # +:associations+ has the same format as the +:include+ option for
      # <tt>ActiveRecord::Base.find</tt>. So +associations+ could look like this:
      #
      #   :books
      #   [ :books, :author ]
      #   { :author => :avatar }
      #   [ :books, { :author => :avatar } ]
      #
      # +preload_options+ contains options that will be passed to ActiveRecord#find
      # (which is called under the hood for preloading records). But it is passed
      # only one level deep in the +associations+ argument, i.e. it's not passed
      # to the child associations when +associations+ is a Hash.
      def preload_associations(records, associations, preload_options={})
        records = [records].flatten.compact.uniq
        return if records.empty?
        case associations
        when Array then associations.each {|association| preload_associations(records, association, preload_options)}
        when Symbol, String then preload_one_association(records, associations.to_sym, preload_options)
        when Hash then
          associations.each do |parent, child|
            raise "parent must be an association name" unless parent.is_a?(String) || parent.is_a?(Symbol)
            preload_associations(records, parent, preload_options)
            reflection = reflections[parent]
            parents = records.map {|record| record.send(reflection.name)}.flatten.compact
            unless parents.empty?
              parents.first.class.preload_associations(parents, child)
            end
          end
        end
      end

      private

      # Preloads a specific named association for the given records. This is
      # called by +preload_associations+ as its base case.
      def preload_one_association(records, association, preload_options={})
        class_to_reflection = {}
        # Not all records have the same class, so group then preload
        # group on the reflection itself so that if various subclass share the same association then we do not split them
        # unnecessarily
        records.group_by {|record| class_to_reflection[record.class] ||= record.class.reflections[association]}.each do |reflection, records|
          raise ConfigurationError, "Association named '#{ association }' was not found; perhaps you misspelled it?" unless reflection

          # 'reflection.macro' can return 'belongs_to', 'has_many', etc. Thus,
          # the following could call 'preload_belongs_to_association',
          # 'preload_has_many_association', etc.
          send("preload_#{reflection.macro}_association", records, reflection, preload_options)
        end
      end

      def add_preloaded_records_to_collection(parent_records, reflection_name, associated_record)
        parent_records.each do |parent_record|
          association_proxy = parent_record.send(reflection_name)
          association_proxy.loaded
          association_proxy.target.push(*[associated_record].flatten)
          association_proxy.__send__(:set_inverse_instance, associated_record, parent_record)
        end
      end

      def add_preloaded_record_to_collection(parent_records, reflection_name, associated_record)
        parent_records.each do |parent_record|
          parent_record.send("set_#{reflection_name}_target", associated_record)
        end
      end

      def set_association_collection_records(id_to_record_map, reflection_name, associated_records, key)
        associated_records.each do |associated_record|
          mapped_records = id_to_record_map[associated_record[key].to_s]
          add_preloaded_records_to_collection(mapped_records, reflection_name, associated_record)
        end
      end

      def set_association_single_records(id_to_record_map, reflection_name, associated_records, key)
        seen_keys = {}
        associated_records.each do |associated_record|
          #this is a has_one or belongs_to: there should only be one record.
          #Unfortunately we can't (in portable way) ask the database for 'all records where foo_id in (x,y,z), but please
          # only one row per distinct foo_id' so this where we enforce that
          next if seen_keys[associated_record[key].to_s]
          seen_keys[associated_record[key].to_s] = true
          mapped_records = id_to_record_map[associated_record[key].to_s]
          mapped_records.each do |mapped_record|
            association_proxy = mapped_record.send("set_#{reflection_name}_target", associated_record)
            association_proxy.__send__(:set_inverse_instance, associated_record, mapped_record)
          end
        end
      end

      # Given a collection of ActiveRecord objects, constructs a Hash which maps
      # the objects' IDs to the relevant objects. Returns a 2-tuple
      # <tt>(id_to_record_map, ids)</tt> where +id_to_record_map+ is the Hash,
      # and +ids+ is an Array of record IDs.
      def construct_id_map(records, primary_key=nil)
        id_to_record_map = {}
        ids = []
        records.each do |record|
          primary_key ||= record.class.primary_key
          ids << record[primary_key]
          mapped_records = (id_to_record_map[ids.last.to_s] ||= [])
          mapped_records << record
        end
        ids.uniq!
        return id_to_record_map, ids
      end

      def preload_has_and_belongs_to_many_association(records, reflection, preload_options={})
        table_name = reflection.klass.quoted_table_name
        id_to_record_map, ids = construct_id_map(records)
        records.each {|record| record.send(reflection.name).loaded}
        options = reflection.options

        conditions = "t0.#{reflection.primary_key_name} #{in_or_equals_for_ids(ids)}"
        conditions << append_conditions(reflection, preload_options)

        associated_records = reflection.klass.with_exclusive_scope do
          reflection.klass.find(:all, :conditions => [conditions, ids],
            :include => options[:include],
            :joins => "INNER JOIN #{connection.quote_table_name options[:join_table]} t0 ON #{reflection.klass.quoted_table_name}.#{reflection.klass.primary_key} = t0.#{reflection.association_foreign_key}",
            :select => "#{options[:select] || table_name+'.*'}, t0.#{reflection.primary_key_name} as the_parent_record_id",
            :order => options[:order])
        end
        set_association_collection_records(id_to_record_map, reflection.name, associated_records, 'the_parent_record_id')
      end

      def preload_has_one_association(records, reflection, preload_options={})
        return if records.first.send("loaded_#{reflection.name}?")
        id_to_record_map, ids = construct_id_map(records, reflection.options[:primary_key])
        options = reflection.options
        records.each {|record| record.send("set_#{reflection.name}_target", nil)}
        if options[:through]
          through_records = preload_through_records(records, reflection, options[:through])
          through_reflection = reflections[options[:through]]
          through_primary_key = through_reflection.primary_key_name
          unless through_records.empty?
            source = reflection.source_reflection.name
            through_records.first.class.preload_associations(through_records, source)
            if through_reflection.macro == :belongs_to
              rev_id_to_record_map, rev_ids = construct_id_map(records, through_primary_key)
              rev_primary_key = through_reflection.klass.primary_key
              through_records.each do |through_record|
                add_preloaded_record_to_collection(rev_id_to_record_map[through_record[rev_primary_key].to_s],
                                                   reflection.name, through_record.send(source))
              end
            else
              through_records.each do |through_record|
                add_preloaded_record_to_collection(id_to_record_map[through_record[through_primary_key].to_s],
                                                   reflection.name, through_record.send(source))
              end
            end
          end
        else
          set_association_single_records(id_to_record_map, reflection.name, find_associated_records(ids, reflection, preload_options), reflection.primary_key_name)
        end
      end

      def preload_has_many_association(records, reflection, preload_options={})
        return if records.first.send(reflection.name).loaded?
        options = reflection.options

        primary_key_name = reflection.through_reflection_primary_key_name
        id_to_record_map, ids = construct_id_map(records, primary_key_name || reflection.options[:primary_key])
        records.each {|record| record.send(reflection.name).loaded}

        if options[:through]
          through_records = preload_through_records(records, reflection, options[:through])
          through_reflection = reflections[options[:through]]
          unless through_records.empty?
            source = reflection.source_reflection.name
            through_records.first.class.preload_associations(through_records, source, options)
            through_records.each do |through_record|
              through_record_id = through_record[reflection.through_reflection_primary_key].to_s
              add_preloaded_records_to_collection(id_to_record_map[through_record_id], reflection.name, through_record.send(source))
            end
          end

        else
          set_association_collection_records(id_to_record_map, reflection.name, find_associated_records(ids, reflection, preload_options),
                                             reflection.primary_key_name)
        end
      end

      def preload_through_records(records, reflection, through_association)
        through_reflection = reflections[through_association]
        through_primary_key = through_reflection.primary_key_name

        if reflection.options[:source_type]
          interface = reflection.source_reflection.options[:foreign_type]
          preload_options = {:conditions => ["#{connection.quote_column_name interface} = ?", reflection.options[:source_type]]}

          records.compact!
          records.first.class.preload_associations(records, through_association, preload_options)

          # Dont cache the association - we would only be caching a subset
          through_records = []
          records.each do |record|
            proxy = record.send(through_association)

            if proxy.respond_to?(:target)
              through_records << proxy.target
              proxy.reset
            else # this is a has_one :through reflection
              through_records << proxy if proxy
            end
          end
          through_records.flatten!
        else
          records.first.class.preload_associations(records, through_association)
          through_records = records.map {|record| record.send(through_association)}.flatten
        end
        through_records.compact!
        through_records
      end

      def preload_belongs_to_association(records, reflection, preload_options={})
        return if records.first.send("loaded_#{reflection.name}?")
        options = reflection.options
        primary_key_name = reflection.primary_key_name

        if options[:polymorphic]
          polymorph_type = options[:foreign_type]
          klasses_and_ids = {}

          # Construct a mapping from klass to a list of ids to load and a mapping of those ids back to their parent_records
          records.each do |record|
            if klass = record.send(polymorph_type)
              klass_id = record.send(primary_key_name)
              if klass_id
                id_map = klasses_and_ids[klass] ||= {}
                id_list_for_klass_id = (id_map[klass_id.to_s] ||= [])
                id_list_for_klass_id << record
              end
            end
          end
          klasses_and_ids = klasses_and_ids.to_a
        else
          id_map = {}
          records.each do |record|
            key = record.send(primary_key_name)
            if key
              mapped_records = (id_map[key.to_s] ||= [])
              mapped_records << record
            end
          end
          klasses_and_ids = [[reflection.klass.name, id_map]]
        end

        klasses_and_ids.each do |klass_and_id|
          klass_name, id_map = *klass_and_id
          next if id_map.empty?
          klass = klass_name.constantize

          table_name = klass.quoted_table_name
          primary_key = klass.primary_key
          column_type = klass.columns.detect{|c| c.name == primary_key}.type
          ids = id_map.keys.map do |id|
            if column_type == :integer
              id.to_i
            elsif column_type == :float
              id.to_f
            else
              id
            end
          end
          conditions = "#{table_name}.#{connection.quote_column_name(primary_key)} #{in_or_equals_for_ids(ids)}"
          conditions << append_conditions(reflection, preload_options)
          associated_records = klass.with_exclusive_scope do
            klass.find(:all, :conditions => [conditions, ids],
                                          :include => options[:include],
                                          :select => options[:select],
                                          :joins => options[:joins],
                                          :order => options[:order])
          end
          set_association_single_records(id_map, reflection.name, associated_records, primary_key)
        end
      end

      def find_associated_records(ids, reflection, preload_options)
        options = reflection.options
        table_name = reflection.klass.quoted_table_name

        if interface = reflection.options[:as]
          conditions = "#{reflection.klass.quoted_table_name}.#{connection.quote_column_name "#{interface}_id"} #{in_or_equals_for_ids(ids)} and #{reflection.klass.quoted_table_name}.#{connection.quote_column_name "#{interface}_type"} = '#{self.base_class.sti_name}'"
        else
          foreign_key = reflection.primary_key_name
          conditions = "#{reflection.klass.quoted_table_name}.#{foreign_key} #{in_or_equals_for_ids(ids)}"
        end

        conditions << append_conditions(reflection, preload_options)

        reflection.klass.with_exclusive_scope do
          reflection.klass.find(:all,
                              :select => (preload_options[:select] || options[:select] || "#{table_name}.*"),
                              :include => preload_options[:include] || options[:include],
                              :conditions => [conditions, ids],
                              :joins => options[:joins],
                              :group => preload_options[:group] || options[:group],
                              :order => preload_options[:order] || options[:order])
        end
      end


      def interpolate_sql_for_preload(sql)
        instance_eval("%@#{sql.gsub('@', '\@')}@")
      end

      def append_conditions(reflection, preload_options)
        sql = ""
        sql << " AND (#{interpolate_sql_for_preload(reflection.sanitized_conditions)})" if reflection.sanitized_conditions
        sql << " AND (#{sanitize_sql preload_options[:conditions]})" if preload_options[:conditions]
        sql
      end

      def in_or_equals_for_ids(ids)
        ids.size > 1 ? "IN (?)" : "= ?"
      end
    end
  end
end
