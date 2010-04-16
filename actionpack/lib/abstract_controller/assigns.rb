module AbstractController
  module Assigns
    # This method should return a hash with assigns.
    # You can overwrite this configuration per controller.
    # :api: public
    def view_assigns
      hash = {}
      variables  = instance_variable_names
      variables -= protected_instance_variables if respond_to?(:protected_instance_variables)
      variables.each { |name| hash[name] = instance_variable_get(name) }
      hash
    end

    # This method assigns the hash specified in _assigns_hash to the given object.
    # :api: private
    # TODO Ideally, this should be done on AV::Base.new initialization.
    def _evaluate_assigns(object)
      view_assigns.each { |k,v| object.instance_variable_set(k, v) }
    end
  end
end