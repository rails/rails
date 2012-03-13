module ActiveResource::Associations::Builder 
  class BelongsTo < Association
    self.valid_options += [:foreign_key]

    self.macro = :belongs_to

    def build
      validate_options
      reflection = model.create_reflection(self.class.macro, name, options)
      model.defines_belongs_to_finder_method(reflection.name, reflection.klass, reflection.foreign_key)
      return reflection
    end
  end
end
