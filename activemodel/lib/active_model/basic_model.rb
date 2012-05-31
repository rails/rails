module ActiveModel

  # == Active Model Basic Model
  #
  # Includes the required interface for an object to interact with <tt>ActionPack</tt>,
  # using different <tt>ActiveModel</tt> modules. It includes model name introspections,
  # conversions, translations and validations.
  #
  # A minimal implementation could be:
  #
  #   class Person
  #     include ActiveModel::BasicModel
  #     attr_accessor :name, :age
  #   end
  #
  # Note that, by default, <tt>ActiveModel::BasicModel</tt> implements <tt>persisted?</tt> to
  # return <tt>false</tt>, which is the most common case. You may want to override it
  # in your class to simulate a different scenario:
  #
  #   class Person
  #     include ActiveModel::BasicModel
  #     attr_accessor :id, :name
  #
  #     def persisted?
  #       self.id == 1
  #     end
  #   end
  #
  #   person = Person.new
  #   person.id = 1
  #   person.persisted? # => true
  #
  # For more detailed information on other functionalities available, please refer
  # to the specific modules included in <tt>ActiveModel::BasicModel</tt> (see below).
  module BasicModel
    def self.included(base)
      base.class_eval do
        extend  ActiveModel::Naming
        extend  ActiveModel::Translation
        include ActiveModel::Validations
        include ActiveModel::Conversion
      end
    end

    def persisted?
      false
    end
  end
end
