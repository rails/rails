module ActionService
  # To send structured types across the wire, derive from ActionService::Struct,
  # and use +member+ to declare structure members.
  #
  # ActionService::Struct should be used in method signatures when you want to accept or return
  # structured types that have no Active Record model class representations, or you don't
  # want to expose your entire Active Record model to remote callers.
  #
  # === Example
  #
  #   class Person < ActionService::Struct
  #     member :id,         :int
  #     member :firstnames, [:string]
  #     member :lastname,   :string
  #     member :email,      :string
  #   end
  #
  # Active Record model classes are already implicitly supported for method
  # return signatures. A structure containing its columns as members will be
  # automatically generated if its present in a signature.
  #
  # The structure 
  class Struct
    
    # If a Hash is given as argument to an ActionService::Struct constructor,
    # containing as key the member name, and its associated initial value
    def initialize(values={})
      if values.is_a?(Hash)
        values.map{|k,v| send('%s=' % k.to_s, v)}
      end
    end

    # The member with the given name
    def [](name)
      send(name.to_s)
    end

    class << self
      include ActionService::Signature

      # Creates a structure member accessible using +name+. Generates
      # accessor methods for reading and writing the member value.
      def member(name, type)
        write_inheritable_hash("struct_members", name => signature_parameter_class(type))
        class_eval <<-END
          def #{name}; @#{name}; end
          def #{name}=(value); @#{name} = value; end
        END
      end
  
      def members # :nodoc:
        read_inheritable_attribute("struct_members") || {}
      end
    end
  end
end
