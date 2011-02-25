module ActiveResource::Associations

  module Builder
    autoload :Association, 'active_resource/associations/builder/association'
    autoload :HasMany,     'active_resource/associations/builder/has_many'
  end



  # 
  #
  #
  #
  def has_many(name, options = {})
    Builder::HasMany.build(self, name, options)
  end 
end
