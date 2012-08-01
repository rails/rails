module ActiveRecord::Associations::Builder
  class HasAndBelongsToMany < CollectionAssociation #:nodoc:
    self.macro = :has_and_belongs_to_many

    self.valid_options += [:join_table, :association_foreign_key, :delete_sql, :insert_sql]

    def build
      reflection = super
      check_validity(reflection)
      define_destroy_hook
      reflection
    end

    private

      def define_destroy_hook
        name = self.name
        model.send(:include, Module.new {
          class_eval <<-RUBY, __FILE__, __LINE__ + 1
            def destroy_associations
              association(#{name.to_sym.inspect}).delete_all_on_destroy
              super
            end
          RUBY
        })
      end

      # TODO: These checks should probably be moved into the Reflection, and we should not be
      #       redefining the options[:join_table] value - instead we should define a
      #       reflection.join_table method.
      def check_validity(reflection)
        if reflection.association_foreign_key == reflection.foreign_key
          raise ActiveRecord::HasAndBelongsToManyAssociationForeignKeyNeeded.new(reflection)
        end

        reflection.options[:join_table] ||= join_table_name(
          model.send(:undecorated_table_name, model.to_s),
          model.send(:undecorated_table_name, reflection.class_name)
        )
      end

      # Generates a join table name from two provided table names.
      # The names in the join table names end up in lexicographic order.
      #
      #   join_table_name("members", "clubs")         # => "clubs_members"
      #   join_table_name("members", "special_clubs") # => "members_special_clubs"
      def join_table_name(first_table_name, second_table_name)
        if first_table_name < second_table_name
          join_table = "#{first_table_name}_#{second_table_name}"
        else
          join_table = "#{second_table_name}_#{first_table_name}"
        end

        model.table_name_prefix + join_table + model.table_name_suffix
      end
  end
end
