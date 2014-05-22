require 'active_model/global_locator'
require 'active_support/core_ext/object/try'

module ActiveJob
  class Arguments
    TYPE_WHITELIST = [ NilClass, Fixnum, Float, String, TrueClass, FalseClass, Hash, Array, Bignum ]

    def self.serialize(arguments)
      arguments.collect do |argument|
        if argument.respond_to?(:global_id)
          argument.global_id
        elsif TYPE_WHITELIST.include?(argument.class)
          argument
        else
          raise "Unsupported argument type: #{argument.class.name}"
        end
      end
    end

    def self.deserialize(arguments)
      arguments.collect { |argument| ActiveModel::GlobalLocator.locate(argument) || argument }
    end
  end
end
