# TODO: Remove in the end, when its functionality is fully integrated in ThroughAssociationScope.

module ActiveRecord
  module Associations
    module NestedHasManyThrough
      def self.included(klass)
        klass.alias_method_chain :construct_conditions, :nesting
        klass.alias_method_chain :construct_joins,      :nesting
      end

      def construct_joins_with_nesting(custom_joins = nil)
        if nested?
          @nested_join_attributes ||= construct_nested_join_attributes
          "#{construct_nested_join_attributes[:joins]} #{@reflection.options[:joins]} #{custom_joins}"
        else
          construct_joins_without_nesting(custom_joins)
        end
      end

      def construct_conditions_with_nesting
        if nested?
          @nested_join_attributes ||= construct_nested_join_attributes
          if @reflection.through_reflection && @reflection.through_reflection.macro == :belongs_to
            "#{@nested_join_attributes[:remote_key]} = #{belongs_to_quoted_key} #{@nested_join_attributes[:conditions]}"
          else
            "#{@nested_join_attributes[:remote_key]} = #{@owner.quoted_id} #{@nested_join_attributes[:conditions]}"
          end
        else
          construct_conditions_without_nesting
        end
      end

      protected

        # Given any belongs_to or has_many (including has_many :through) association,
        # return the essential components of a join corresponding to that association, namely:
        #
        # * <tt>:joins</tt>: any additional joins required to get from the association's table
        #   (reflection.table_name) to the table that's actually joining to the active record's table
        # * <tt>:remote_key</tt>: the name of the key in the join table (qualified by table name) which will join
        #   to a field of the active record's table
        # * <tt>:local_key</tt>: the name of the key in the local table (not qualified by table name) which will
        #   take part in the join
        # * <tt>:conditions</tt>: any additional conditions (e.g. filtering by type for a polymorphic association,
        #    or a :conditions clause explicitly given in the association), including a leading AND
        def construct_nested_join_attributes(reflection = @reflection, association_class = reflection.klass, table_ids = {association_class.table_name => 1})
          if (reflection.macro == :has_many || reflection.macro == :has_one) && reflection.through_reflection
            construct_has_many_through_attributes(reflection, table_ids)
          else
            construct_has_many_or_belongs_to_attributes(reflection, association_class, table_ids)
          end
        end

        def construct_has_many_through_attributes(reflection, table_ids)
          # Construct the join components of the source association, so that we have a path from
          # the eventual target table of the association up to the table named in :through, and
          # all tables involved are allocated table IDs.
          source_attrs = construct_nested_join_attributes(reflection.source_reflection, reflection.klass, table_ids)

          # Determine the alias of the :through table; this will be the last table assigned
          # when constructing the source join components above.
          through_table_alias = through_table_name = reflection.through_reflection.table_name
          through_table_alias += "_#{table_ids[through_table_name]}" unless table_ids[through_table_name] == 1

          # Construct the join components of the through association, so that we have a path to
          # the active record's table.
          through_attrs = construct_nested_join_attributes(reflection.through_reflection, reflection.through_reflection.klass, table_ids)

          # Any subsequent joins / filters on owner attributes will act on the through association,
          # so that's what we return for the conditions/keys of the overall association.
          conditions = through_attrs[:conditions]
          conditions += " AND #{interpolate_sql(reflection.klass.send(:sanitize_sql, reflection.options[:conditions]))}" if reflection.options[:conditions]

          {
            :joins => "%s INNER JOIN %s ON ( %s = %s.%s %s) %s %s" % [
              source_attrs[:joins],
              through_table_name == through_table_alias ? through_table_name : "#{through_table_name} #{through_table_alias}",
              source_attrs[:remote_key],
              through_table_alias, source_attrs[:local_key],
              source_attrs[:conditions],
              through_attrs[:joins],
              reflection.options[:joins]
            ],
            :remote_key => through_attrs[:remote_key],
            :local_key => through_attrs[:local_key],
            :conditions => conditions
          }
        end

        # reflection is not has_many :through; it's a standard has_many / belongs_to instead
        # TODO: see if we can defer to rails code here a bit more
        def construct_has_many_or_belongs_to_attributes(reflection, association_class, table_ids)
          # Determine the alias used for remote_table_name, if any. In all cases this will already
          # have been assigned an ID in table_ids (either through being involved in a previous join,
          # or - if it's the first table in the query - as the default value of table_ids)
          remote_table_alias = remote_table_name = association_class.table_name
          remote_table_alias += "_#{table_ids[remote_table_name]}" unless table_ids[remote_table_name] == 1

          # Assign a new alias for the local table.
          local_table_alias = local_table_name = reflection.active_record.table_name
          if table_ids[local_table_name]
            table_id = table_ids[local_table_name] += 1
            local_table_alias += "_#{table_id}"
          else
            table_ids[local_table_name] = 1
          end

          conditions = ''
          # Add type_condition, if applicable
          conditions += " AND #{association_class.send(:type_condition).to_sql}" if association_class.finder_needs_type_condition?
          # Add custom conditions
          conditions += " AND (#{interpolate_sql(association_class.send(:sanitize_sql, reflection.options[:conditions]))})" if reflection.options[:conditions]

          if reflection.macro == :belongs_to
            if reflection.options[:polymorphic]
              conditions += " AND #{local_table_alias}.#{reflection.options[:foreign_type]} = #{reflection.active_record.quote_value(association_class.base_class.name.to_s)}"
            end
            {
              :joins => reflection.options[:joins],
              :remote_key => "#{remote_table_alias}.#{association_class.primary_key}",
              :local_key => reflection.primary_key_name,
              :conditions => conditions
            }
          else
            # Association is has_many (without :through)
            if reflection.options[:as]
              conditions += " AND #{remote_table_alias}.#{reflection.options[:as]}_type = #{reflection.active_record.quote_value(reflection.active_record.base_class.name.to_s)}"
            end
            {
              :joins => "#{reflection.options[:joins]}",
              :remote_key => "#{remote_table_alias}.#{reflection.primary_key_name}",
              :local_key => reflection.klass.primary_key,
              :conditions => conditions
            }
          end
        end

        def belongs_to_quoted_key
          attribute = @reflection.through_reflection.primary_key_name
          column    = @owner.column_for_attribute attribute

          @owner.send(:quote_value, @owner.send(attribute), column)
        end

        def nested?
          through_source_reflection? || through_through_reflection?
        end

        def through_source_reflection?
          @reflection.source_reflection && @reflection.source_reflection.options[:through]
        end

        def through_through_reflection?
          @reflection.through_reflection && @reflection.through_reflection.options[:through]
        end
    end
  end
end
