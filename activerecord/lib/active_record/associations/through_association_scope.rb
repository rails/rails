require 'enumerator'

module ActiveRecord
  # = Active Record Through Association Scope
  module Associations
    module ThroughAssociationScope

      protected

      def construct_scope
        { :create => construct_owner_attributes(@reflection),
          :find   => { :conditions  => construct_conditions,
                       :joins       => construct_joins,
                       :include     => @reflection.options[:include] || @reflection.source_reflection.options[:include],
                       :select      => construct_select,
                       :order       => @reflection.options[:order],
                       :limit       => @reflection.options[:limit],
                       :readonly    => @reflection.options[:readonly],
           } }
      end

      # Build SQL conditions from attributes, qualified by table name.
      # TODO: Conditions on joins
      def construct_conditions
        reflection = @reflection.through_reflection_chain.last
        conditions = construct_quoted_owner_attributes(reflection).map do |attr, value|
          "#{table_aliases[reflection]}.#{attr} = #{value}"
        end
        conditions << sql_conditions if sql_conditions
        "(" + conditions.join(') AND (') + ")"
      end

      # Associate attributes pointing to owner, quoted.
      def construct_quoted_owner_attributes(reflection)
        if as = reflection.options[:as]
          { "#{as}_id" => owner_quoted_id,
            "#{as}_type" => reflection.klass.quote_value(
              @owner.class.base_class.name.to_s,
              reflection.klass.columns_hash["#{as}_type"]) }
        elsif reflection.macro == :belongs_to
          { reflection.klass.primary_key => @owner.class.quote_value(@owner[reflection.primary_key_name]) }
        else
          { reflection.primary_key_name => owner_quoted_id }
        end
      end

      def construct_from
        @reflection.table_name
      end

      def construct_select(custom_select = nil)
        distinct = "DISTINCT " if @reflection.options[:uniq]
        selected = custom_select || @reflection.options[:select] || "#{distinct}#{@reflection.quoted_table_name}.*"
      end
      
      def construct_joins(custom_joins = nil)
        # p @reflection.through_reflection_chain
        
        "#{construct_through_joins} #{@reflection.options[:joins]} #{custom_joins}"
      end

      def construct_through_joins
        joins = []
        
        # Iterate over each pair in the through reflection chain, joining them together
        @reflection.through_reflection_chain.each_cons(2) do |left, right|
          polymorphic_join  = nil
          left_table, right_table = table_aliases[left], table_aliases[right]
          
          if left.source_reflection.nil?
            # TODO: Perhaps need to pay attention to left.options[:primary_key] and
            # left.options[:foreign_key] in places here
            
            case left.macro
              when :belongs_to
                left_primary_key  = left.klass.primary_key
                right_primary_key = left.primary_key_name
              when :has_many, :has_one
                left_primary_key  = left.primary_key_name
                right_primary_key = right.klass.primary_key
                
                if left.options[:as]
                  polymorphic_join = "AND %s.%s = %s" % [
                    table_aliases[left], "#{left.options[:as]}_type",
                    # TODO: Why right.klass.name? Rather than left.active_record.name?
                    # TODO: Also should maybe use the base_class (see related code in JoinAssociation)
                    @owner.class.quote_value(right.klass.name)
                  ]
                end
              when :has_and_belongs_to_many
                raise NotImplementedError
            end
          else
            case left.source_reflection.macro
              when :belongs_to
                left_primary_key  = left.klass.primary_key
                right_primary_key = left.source_reflection.primary_key_name
                
                if left.options[:source_type]
                  polymorphic_join = "AND %s.%s = %s" % [
                    table_aliases[right],
                    left.source_reflection.options[:foreign_type].to_s,
                    @owner.class.quote_value(left.options[:source_type])
                  ]
                end
              when :has_many, :has_one
                left_primary_key  = left.source_reflection.primary_key_name
                right_primary_key = right.klass.primary_key
                
                if left.source_reflection.options[:as]
                  polymorphic_join = "AND %s.%s = %s" % [
                    table_aliases[left],
                    "#{left.source_reflection.options[:as]}_type",
                    @owner.class.quote_value(right.klass.name)
                  ]
                end
              when :has_and_belongs_to_many
                join_table, left_table = left_table
                
                left_primary_key = left.klass.primary_key
                join_primary_key = left.source_reflection.association_foreign_key
                
                joins << "INNER JOIN %s ON %s.%s = %s.%s" % [
                  table_name_and_alias(
                    quote_table_name(left.source_reflection.options[:join_table]),
                    join_table
                  ),
                  left_table, left_primary_key,
                  join_table, join_primary_key
                ]
                
                left_table = join_table
                
                left_primary_key  = left.source_reflection.primary_key_name
                right_primary_key = right.klass.primary_key
            end
          end
          
          joins << "INNER JOIN %s ON %s.%s = %s.%s %s" % [
            table_name_and_alias(right.quoted_table_name, right_table),
            left_table,  left_primary_key,
            right_table, right_primary_key,
            polymorphic_join
          ]
        end
        
        joins.join(" ")
      end

      def alias_tracker
        @alias_tracker ||= AliasTracker.new
      end

      def table_aliases
        @table_aliases ||= begin
          @reflection.through_reflection_chain.inject({}) do |aliases, reflection|
            table_alias = quote_table_name(alias_tracker.aliased_name_for(
              reflection.table_name,
              table_alias_for(reflection, reflection != @reflection)
            ))
            
            if reflection.macro == :has_and_belongs_to_many ||
                 (reflection.source_reflection &&
                  reflection.source_reflection.macro == :has_and_belongs_to_many)
              
              join_table_alias = quote_table_name(alias_tracker.aliased_name_for(
                (reflection.source_reflection || reflection).options[:join_table],
                table_alias_for(reflection, true)
              ))
              
              aliases[reflection] = [join_table_alias, table_alias]
            else
              aliases[reflection] = table_alias
            end
            
            aliases
          end
        end
      end
      
      def table_alias_for(reflection, join = false)
        name = alias_tracker.pluralize(reflection.name)
        name << "_#{@reflection.name}"
        name << "_join" if join
        name
      end
      
      def quote_table_name(table_name)
        @reflection.klass.connection.quote_table_name(table_name)
      end
      
      def table_name_and_alias(table_name, table_alias)
        "#{table_name} #{table_alias if table_alias != table_name}".strip
      end

      # Construct attributes for associate pointing to owner.
      def construct_owner_attributes(reflection)
        if as = reflection.options[:as]
          { "#{as}_id" => @owner.id,
            "#{as}_type" => @owner.class.base_class.name.to_s }
        else
          { reflection.primary_key_name => @owner.id }
        end
      end

      # Construct attributes for :through pointing to owner and associate.
      def construct_join_attributes(associate)
        # TODO: revisit this to allow it for deletion, supposing dependent option is supported
        raise ActiveRecord::HasManyThroughCantAssociateThroughHasOneOrManyReflection.new(@owner, @reflection) if [:has_one, :has_many].include?(@reflection.source_reflection.macro)

        join_attributes = construct_owner_attributes(@reflection.through_reflection).merge(@reflection.source_reflection.primary_key_name => associate.id)

        if @reflection.options[:source_type]
          join_attributes.merge!(@reflection.source_reflection.options[:foreign_type] => associate.class.base_class.name.to_s)
        end

        if @reflection.through_reflection.options[:conditions].is_a?(Hash)
          join_attributes.merge!(@reflection.through_reflection.options[:conditions])
        end

        join_attributes
      end

      def conditions
        @conditions = build_conditions unless defined?(@conditions)
        @conditions
      end

      def build_conditions
        association_conditions = @reflection.options[:conditions]
        through_conditions = build_through_conditions
        source_conditions = @reflection.source_reflection.options[:conditions]
        uses_sti = !@reflection.through_reflection.klass.descends_from_active_record?

        if association_conditions || through_conditions || source_conditions || uses_sti
          all = []

          [association_conditions, source_conditions].each do |conditions|
            all << interpolate_sql(sanitize_sql(conditions)) if conditions
          end

          all << through_conditions  if through_conditions
          all << build_sti_condition if uses_sti

          all.map { |sql| "(#{sql})" } * ' AND '
        end
      end

      def build_through_conditions
        conditions = @reflection.through_reflection.options[:conditions]
        if conditions.is_a?(Hash)
          interpolate_sql(@reflection.through_reflection.klass.send(:sanitize_sql, conditions)).gsub(
            @reflection.quoted_table_name,
            @reflection.through_reflection.quoted_table_name)
        elsif conditions
          interpolate_sql(sanitize_sql(conditions))
        end
      end

      def build_sti_condition
        @reflection.through_reflection.klass.send(:type_condition).to_sql
      end

      alias_method :sql_conditions, :conditions
    end
  end
end
