require 'active_resource/exceptions'

module ActiveResource # :nodoc:
  class Schema # :nodoc:
    # attributes can be known to be one of these types. They are easy to
    # cast to/from.
    KNOWN_ATTRIBUTE_TYPES = %w( string integer float )

    # An array of attribute definitions, representing the attributes that
    # have been defined.
    attr_accessor :attrs

    # The internals of an Active Resource Schema are very simple -
    # unlike an Active Record TableDefinition (on which it is based).
    # It provides a set of convenience methods for people to define their
    # schema using the syntax:
    #  schema do
    #    string :foo
    #    integer :bar
    #  end
    #
    #  The schema stores the name and type of each attribute. That is then
    #  read out by the schema method to populate the actual
    #  Resource's schema
    def initialize
      @attrs = {}
    end

    def attribute(name, type, options = {})
      raise ArgumentError, "Unknown Attribute type: #{type.inspect} for key: #{name.inspect}" unless type.nil? || Schema::KNOWN_ATTRIBUTE_TYPES.include?(type.to_s)

      the_type = type.to_s
      # TODO: add defaults
      #the_attr = [type.to_s]
      #the_attr << options[:default] if options.has_key? :default
      @attrs[name.to_s] = the_type
      self
    end

    # The following are the attribute types supported by Active Resource
    # migrations.
    # TODO:  We should eventually support all of these:
    # %w( string text integer float decimal datetime timestamp time date binary boolean ).each do |attr_type|
    KNOWN_ATTRIBUTE_TYPES.each do |attr_type|
      class_eval <<-EOV, __FILE__, __LINE__ + 1
        def #{attr_type.to_s}(*args)
          options = args.extract_options!
          attr_names = args

          attr_names.each { |name| attribute(name, '#{attr_type}', options) }
        end
      EOV
    end
  end
end
