module ActiveModel
  # When you have a module
  #   
  #   module Foo
  #     extend ActiveModel::InjectValidations
  #
  #     inject_validations do |c|
  #       c.validates_presence_of :price
  #     end
  #   end
  #
  # and a model
  #
  #   class Offer < ActiveRecord::Base ; end
  #
  # and you extend an instance of +Offer+ like this
  #
  #   offer = Offer.new
  #   offer.extend(Foo)
  #
  # The validation behaviour of +offer+, and only that instance,
  # will be the same as if you had
  #
  #   class Offer < ActiveRecord::base
  #     validates_presence_of :price
  #   end
  #
  # It assumes that all validation is done with the valid? method on the object,
  # which is the case for the current version of ActiveModel (3.2.3).
  module InjectValidations

    def inject_validations(&block)
      @validations = block
    end

    private

    def self.extended(base)
      base.module_eval do
        def self.extended(real_base)
          super(real_base)
          context_sym = (self.name.gsub(":","").to_s + "Context").underscore.to_sym
          
          # Do not redefine validations on base class, if already included once.
          sym = ("@@" + context_sym.to_s).to_sym
          unless real_base.class.class_variable_defined?(sym)
            real_base.class.class_variable_set(sym, true)
            vs = @validations
            real_base.class.instance_eval do
              with_options :on => context_sym, &vs
            end
          end
          
          real_base.define_singleton_method(:valid?) do |context=nil|
            valid = super(context_sym)
            unless context.nil?
              _errors = errors.to_hash
              valid &= super(context)
              
              # Merge errors from both contexts
              _errors.each { |k,v| errors.set(k, (_errors[k] + v).uniq) }
            end
            valid
          end
        end
      end
    end
  end
end