# frozen_string_literal: true

module ActiveModel
  # = Active \Model \Conversion
  #
  # Handles default conversions: #to_model, #to_key, #to_param, and #to_partial_path.
  #
  # Let's take for example this non-persisted object.
  #
  #   class ContactMessage
  #     include ActiveModel::Conversion
  #
  #     # ContactMessage are never persisted in the DB
  #     def persisted?
  #       false
  #     end
  #   end
  #
  #   cm = ContactMessage.new
  #   cm.to_model == cm  # => true
  #   cm.to_key          # => nil
  #   cm.to_param        # => nil
  #   cm.to_partial_path # => "contact_messages/contact_message"
  module Conversion
    extend ActiveSupport::Concern

    included do
      ##
      # :singleton-method:
      #
      # Accepts a string that will be used as a delimiter of object's key values in the `to_param` method,
      # and when parsing params back with +param_to_key+. Default is <tt>"-"</tt>.
      #
      # Note: Parsing by splitting on +param_delimiter+ is ambiguous if a single id can contain the
      # delimiter. For example, with the default <tt>"-"</tt>, an id of <tt>"a-b"</tt> would be
      # serialized as <tt>"a-b"</tt>, and <tt>param_to_key("a-b")</tt> would return <tt>["a", "b"]</tt>,
      # not <tt>["a-b"]</tt>. Avoid using delimiter characters in composite key segments, or use a
      # custom delimiter that does not appear in your ids.
      class_attribute :param_delimiter, instance_reader: false, default: "-"
    end

    # If your object is already designed to implement all of the \Active \Model
    # you can use the default <tt>:to_model</tt> implementation, which simply
    # returns +self+.
    #
    #   class Person
    #     include ActiveModel::Conversion
    #   end
    #
    #   person = Person.new
    #   person.to_model == person # => true
    #
    # If your model does not act like an \Active \Model object, then you should
    # define <tt>:to_model</tt> yourself returning a proxy object that wraps
    # your object with \Active \Model compliant methods.
    def to_model
      self
    end

    # Returns an Array of all key attributes if any of the attributes is set, whether or not
    # the object is persisted. Returns +nil+ if there are no key attributes.
    #
    #   class Person
    #     include ActiveModel::Conversion
    #     attr_accessor :id
    #
    #     def initialize(id)
    #       @id = id
    #     end
    #   end
    #
    #   person = Person.new(1)
    #   person.to_key # => [1]
    def to_key
      key = respond_to?(:id) && id
      key ? Array(key) : nil
    end

    # Returns a +string+ representing the object's key suitable for use in URLs,
    # or +nil+ if <tt>persisted?</tt> is +false+.
    #
    #   class Person
    #     include ActiveModel::Conversion
    #     attr_accessor :id
    #
    #     def initialize(id)
    #       @id = id
    #     end
    #
    #     def persisted?
    #       true
    #     end
    #   end
    #
    #   person = Person.new(1)
    #   person.to_param # => "1"
    def to_param
      persisted? ? self.class.key_to_param(to_key) : nil
    end

    # Returns a +string+ identifying the path associated with the object.
    # ActionPack uses this to find a suitable partial to represent the object.
    #
    #   class Person
    #     include ActiveModel::Conversion
    #   end
    #
    #   person = Person.new
    #   person.to_partial_path # => "people/person"
    def to_partial_path
      self.class._to_partial_path
    end

    module ClassMethods # :nodoc:
      # Provide a class level cache for #to_partial_path. This is an
      # internal method and should not be accessed directly.
      def _to_partial_path # :nodoc:
        @_to_partial_path ||= if respond_to?(:model_name)
          "#{model_name.collection}/#{model_name.element}"
        else
          element = ActiveSupport::Inflector.underscore(ActiveSupport::Inflector.demodulize(name))
          collection = ActiveSupport::Inflector.tableize(name)
          "#{collection}/#{element}"
        end
      end

      # Converts a param string (e.g. from a URL or form) back into a key array using the
      # class's +param_delimiter+. Returns +nil+ when +param+ is +nil+.
      #
      #   Person.param_to_key("1")           # => ["1"]
      #   Person.param_to_key("1-2")         # => ["1", "2"]
      #   Person.param_to_key(nil)           # => nil
      #
      # See +param_delimiter+ for the note on ambiguity when a single id contains the delimiter.
      def param_to_key(param)
        param&.split(param_delimiter)
      end

      # Converts a key array (e.g. from +to_key+) into a param string using the class's
      # +param_delimiter+. Returns +nil+ when +key+ is not a non-empty array of all truthy elements.
      #
      #   Person.key_to_param([1])           # => "1"
      #   Person.key_to_param([1, 2])        # => "1-2"
      #   Person.key_to_param(nil)           # => nil
      #   Person.key_to_param([1, nil])      # => nil
      def key_to_param(key)
        (key.is_a?(Array) && key.all?) ? key.join(param_delimiter) : nil
      end
    end
  end
end
