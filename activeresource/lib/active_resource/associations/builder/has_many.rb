module ActiveResource::Associations::Builder 
  class HasMany < Associations
    self.macro = :has_many 
  end
end
