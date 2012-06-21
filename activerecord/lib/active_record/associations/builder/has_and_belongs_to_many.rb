module ActiveRecord::Associations::Builder
  class HasAndBelongsToMany < CollectionAssociation #:nodoc:
    self.macro = :has_and_belongs_to_many

    self.valid_options += [:join_table, :association_foreign_key, :delete_sql, :insert_sql]

    def build
      reflection = super
      define_destroy_hook
      reflection
    end

    private

      def define_destroy_hook
        name = self.name
        model.send(:include, Module.new {
          class_eval <<-RUBY, __FILE__, __LINE__ + 1
            def destroy_associations
              association(#{name.to_sym.inspect}).delete_all
              super
            end
          RUBY
        })
      end
  end
end
