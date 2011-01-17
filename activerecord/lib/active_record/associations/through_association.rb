module ActiveRecord
  # = Active Record Through Association
  module Associations
    module ThroughAssociation

      protected

      def target_scope
        super & @reflection.through_reflection.klass.scoped
      end

      def association_scope
        scope = super.joins(construct_joins).where(conditions)
        unless @reflection.options[:include]
          scope = scope.includes(@reflection.source_reflection.options[:include])
        end
        scope
      end

      # This scope affects the creation of the associated records (not the join records). At the
      # moment we only support creating on a :through association when the source reflection is a
      # belongs_to. Thus it's not necessary to set a foreign key on the associated record(s), so
      # this scope has can legitimately be empty.
      def creation_attributes
        { }
      end

      def aliased_through_table
        name = @reflection.through_reflection.table_name

        @reflection.table_name == name ?
          @reflection.through_reflection.klass.arel_table.alias(name + "_join") :
          @reflection.through_reflection.klass.arel_table
      end

      def construct_owner_conditions
        super(aliased_through_table, @reflection.through_reflection)
      end

      def construct_joins
        right = aliased_through_table
        left  = @reflection.klass.arel_table

        conditions = []

        if @reflection.source_reflection.macro == :belongs_to
          reflection_primary_key = @reflection.source_reflection.options[:primary_key] ||
                                   @reflection.klass.primary_key
          source_primary_key     = @reflection.source_reflection.foreign_key
          if @reflection.options[:source_type]
            column = @reflection.source_reflection.foreign_type
            conditions <<
              right[column].eq(@reflection.options[:source_type])
          end
        else
          reflection_primary_key = @reflection.source_reflection.foreign_key
          source_primary_key     = @reflection.source_reflection.options[:primary_key] ||
                                   @reflection.through_reflection.klass.primary_key
          if @reflection.source_reflection.options[:as]
            column = "#{@reflection.source_reflection.options[:as]}_type"
            conditions <<
              left[column].eq(@reflection.through_reflection.klass.name)
          end
        end

        conditions <<
          left[reflection_primary_key].eq(right[source_primary_key])

        right.create_join(
          right,
          right.create_on(right.create_and(conditions)))
      end

      # Construct attributes for :through pointing to owner and associate.
      def construct_join_attributes(associate)
        # TODO: revisit this to allow it for deletion, supposing dependent option is supported
        raise ActiveRecord::HasManyThroughCantAssociateThroughHasOneOrManyReflection.new(@owner, @reflection) if [:has_one, :has_many].include?(@reflection.source_reflection.macro)

        join_attributes = {
          @reflection.source_reflection.foreign_key =>
            associate.send(@reflection.source_reflection.association_primary_key)
        }

        if @reflection.options[:source_type]
          join_attributes.merge!(@reflection.source_reflection.foreign_type => associate.class.base_class.name)
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
        through_conditions = build_through_conditions
        source_conditions = @reflection.source_reflection.options[:conditions]
        uses_sti = !@reflection.through_reflection.klass.descends_from_active_record?

        if through_conditions || source_conditions || uses_sti
          all = []
          all << interpolate_sql(sanitize_sql(source_conditions)) if source_conditions
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

      def stale_state
        if @reflection.through_reflection.macro == :belongs_to
          @owner[@reflection.through_reflection.foreign_key].to_s
        end
      end

      def foreign_key_present?
        @reflection.through_reflection.macro == :belongs_to &&
        !@owner[@reflection.through_reflection.foreign_key].nil?
      end
    end
  end
end
