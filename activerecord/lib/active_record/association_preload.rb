module ActiveRecord
  module AssociationPreload #:nodoc:
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods

      # Loads the named associations for the activerecord record (or records) given
      # preload_options is passed only one level deep: don't pass to the child associations when associations is a Hash
      protected
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
            parents = records.map {|record| record.send(reflection.name)}.flatten
            unless parents.empty? || parents.first.nil?
              parents.first.class.preload_associations(parents, child)
            end
          end
        end
      end

      private

      def preload_one_association(records, association, preload_options={})
        class_to_reflection = {}
        # Not all records have the same class, so group then preload
        # group on the reflection itself so that if various subclass share the same association then we do not split them
        # unncessarily
        records.group_by {|record| class_to_reflection[record.class] ||= record.class.reflections[association]}.each do |reflection, records|
          raise ConfigurationError, "Association named '#{ association }' was not found; perhaps you misspelled it?" unless reflection
          send("preload_#{reflection.macro}_association", records, reflection, preload_options)
        end
      end

      def add_preloaded_records_to_collection(parent_records, reflection_name, associated_record)
        parent_records.each do |parent_record|
          association_proxy = parent_record.send(reflection_name)
          association_proxy.loaded
          association_proxy.target.push(*[associated_record].flatten)
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
            mapped_record.send("set_#{reflection_name}_target", associated_record)
          end
        end
      end

      def construct_id_map(records)
        id_to_record_map = {}
        ids = []
        records.each do |record|
          ids << record.id
          mapped_records = (id_to_record_map[record.id.to_s] ||= [])
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

        associated_records = reflection.klass.find(:all, :conditions => [conditions, ids],
        :include => options[:include],
        :joins => "INNER JOIN #{connection.quote_table_name options[:join_table]} as t0 ON #{reflection.klass.quoted_table_name}.#{reflection.klass.primary_key} = t0.#{reflection.association_foreign_key}",
        :select => "#{options[:select] || table_name+'.*'}, t0.#{reflection.primary_key_name} as the_parent_record_id",
        :order => options[:order])

        set_association_collection_records(id_to_record_map, reflection.name, associated_records, 'the_parent_record_id')
      end

      def preload_has_one_association(records, reflection, preload_options={})
        id_to_record_map, ids = construct_id_map(records)        
        options = reflection.options
        records.each {|record| record.send("set_#{reflection.name}_target", nil)}
        if options[:through]
          through_records = preload_through_records(records, reflection, options[:through])
          through_reflection = reflections[options[:through]]
          through_primary_key = through_reflection.primary_key_name
          unless through_records.empty?
            source = reflection.source_reflection.name
            through_records.first.class.preload_associations(through_records, source)
            through_records.each do |through_record|
              add_preloaded_record_to_collection(id_to_record_map[through_record[through_primary_key].to_s],
                                                 reflection.name, through_record.send(source))
            end
          end
        else
          set_association_single_records(id_to_record_map, reflection.name, find_associated_records(ids, reflection, preload_options), reflection.primary_key_name)
        end
      end

      def preload_has_many_association(records, reflection, preload_options={})
        id_to_record_map, ids = construct_id_map(records)
        records.each {|record| record.send(reflection.name).loaded}
        options = reflection.options

        if options[:through]
          through_records = preload_through_records(records, reflection, options[:through])
          through_reflection = reflections[options[:through]]
          through_primary_key = through_reflection.primary_key_name
          unless through_records.empty?
            source = reflection.source_reflection.name
            #add conditions from reflection!
            through_records.first.class.preload_associations(through_records, source, reflection.options)
            through_records.each do |through_record|
              add_preloaded_records_to_collection(id_to_record_map[through_record[through_primary_key].to_s],
                                                 reflection.name, through_record.send(source))
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
          klass = klass_name.constantize

          table_name = klass.quoted_table_name
          primary_key = klass.primary_key
          column_type = klass.columns.detect{|c| c.name == primary_key}.type
          ids = id_map.keys.uniq.map do |id|
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
          associated_records = klass.find(:all, :conditions => [conditions, ids],
                                          :include => options[:include],
                                          :select => options[:select],
                                          :joins => options[:joins],
                                          :order => options[:order])
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

        reflection.klass.find(:all,
                              :select => (preload_options[:select] || options[:select] || "#{table_name}.*"),
                              :include => preload_options[:include] || options[:include],
                              :conditions => [conditions, ids],
                              :joins => options[:joins],
                              :group => preload_options[:group] || options[:group],
                              :order => preload_options[:order] || options[:order])
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
