module ActiveResource::Associations::Builder 
  class HasMany < Association
    self.macro = :has_many 
  end
end
