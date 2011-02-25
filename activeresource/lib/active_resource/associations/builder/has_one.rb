module ActiveResource::Associations::Builder 
  class HasOne < Associations
    self.macro = :has_one
  end
end
