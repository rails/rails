module ActiveResource::Associations::Builder
  class Association #:nodoc:

    # providing a Class-Variable, which will have a differend store of subclasses
    class_attribute :valid_options
    self.valid_options = [:class_name]

    # would identify subclasses of association
    class_attribute :macro

    attr_reader :model, :name, :options, :klass

    def self.build(model, name, options)
      new(model, name, options).build
    end

    def initialize(model, name, options)
      @model, @name, @options = model, name, options
    end

    def build
      validate_options
      reflection = model.create_reflection(self.class.macro, name, options)
    end

    private

    def validate_options
      options.assert_valid_keys(self.class.valid_options)
    end
  end
end
