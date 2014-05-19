require 'active_model/global_locator'
require 'active_support/core_ext/object/try'

module ActiveJob
  class Parameters
    TYPE_WHITELIST = [NilClass, Fixnum, Float, String, TrueClass, FalseClass, Hash, Array]

    def self.serialize(params)
      params.collect do |param|
        raise "Unsupported parameter type: #{param.class.name}" unless param.respond_to?(:global_id) || TYPE_WHITELIST.include?(param.class)
        param.try(:global_id) || param
      end
    end

    def self.deserialize(params)
      params.collect { |param| ActiveModel::GlobalLocator.locate(param) || param }
    end
  end
end
