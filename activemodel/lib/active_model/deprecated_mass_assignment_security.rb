module ActiveModel
  module DeprecatedMassAssignmentSecurity # :nodoc:
    extend ActiveSupport::Concern

     module ClassMethods # :nodoc:
       def attr_protected(*args)
         raise "`attr_protected` is extracted out of Rails into a gem. " \
           "Please use new recommended protection model for params " \
           "or add `protected_attributes` to your Gemfile to use old one."
       end

       def attr_accessible(*args)
         raise "`attr_accessible` is extracted out of Rails into a gem. " \
           "Please use new recommended protection model for params " \
           "or add `protected_attributes` to your Gemfile to use old one."
       end
     end
  end
end
