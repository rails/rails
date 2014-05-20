require 'active_model/global_locator'
require 'active_support/core_ext/object/try'

module ActiveJob
  class Parameters
    TYPE_WHITELIST = [ NilClass, Fixnum, Float, String, TrueClass, FalseClass, Hash, Array, Bignum ]

    def self.serialize(params)
      params.collect do |param|
        if param.respond_to?(:global_id)
          param.global_id
        elsif TYPE_WHITELIST.include?(param.class)
          param
        else
          raise "Unsupported parameter type: #{param.class.name}"
        end
      end
    end

    def self.deserialize(params)
      params.collect { |param| ActiveModel::GlobalLocator.locate(param) || param }
    end
  end
end
