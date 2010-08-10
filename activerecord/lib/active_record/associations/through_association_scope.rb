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
      def construct_conditions
        table_name = @reflection.through_reflection.quoted_table_name
        conditions = construct_quoted_owner_attributes(@reflection.through_reflection).map do |attr, value|
          "#{table_name}.#{attr} = #{value}"
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
        polymorphic_join = nil
        if @reflection.source_reflection.macro == :belongs_to
          reflection_primary_key = @reflection.klass.primary_key
          source_primary_key     = @reflection.source_reflection.primary_key_name
          if @reflection.options[:source_type]
            polymorphic_join = "AND %s.%s = %s" % [
              @reflection.through_reflection.quoted_table_name, "#{@reflection.source_reflection.options[:foreign_type]}",
              @owner.class.quote_value(@reflection.options[:source_type])
            ]
          end
        else
          reflection_primary_key = @reflection.source_reflection.primary_key_name
          source_primary_key     = @reflection.through_reflection.klass.primary_key
          if @reflection.source_reflection.options[:as]
            polymorphic_join = "AND %s.%s = %s" % [
              @reflection.quoted_table_name, "#{@reflection.source_reflection.options[:as]}_type",
              @owner.class.quote_value(@reflection.through_reflection.klass.name)
            ]
          end
        end

        "INNER JOIN %s ON %s.%s = %s.%s %s #{@reflection.options[:joins]} #{custom_joins}" % [
          @reflection.through_reflection.quoted_table_name,
          @reflection.quoted_table_name, reflection_primary_key,
          @reflection.through_reflection.quoted_table_name, source_primary_key,
          polymorphic_join
        ]
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
