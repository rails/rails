require 'active_model/global_locator'
require 'active_support/core_ext/object/try'

module ActiveJob
  class Parameters
    def self.serialize(params)
      params.collect { |param| param.try(:global_id) || param }
    end
    
    def self.deserialize(params)
      params.collect { |param| ActiveModel::GlobalLocator.locate(param) || param }
    end
  end
end
  