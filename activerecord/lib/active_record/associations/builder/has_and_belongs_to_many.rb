module ActiveRecord::Associations::Builder
  class HasAndBelongsToMany < CollectionAssociation #:nodoc:
    def macro
      :has_and_belongs_to_many
    end

    def valid_options
      super + [:join_table, :association_foreign_key]
    end

    def define_callbacks(model, reflection)
      super
      name = reflection.name
      model.send(:include, Module.new {
        class_eval <<-RUBY, __FILE__, __LINE__ + 1
          def destroy_associations
            association(:#{name}).delete_all
            super
          end
        RUBY
      })
    end
  end
end
