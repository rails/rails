module ActiveModel
  module Lint
    # == Active \Model \Lint \Tests
    #
    # You can test whether an object is compliant with the Active \Model API by
    # including <tt>ActiveModel::Lint::Tests</tt> in your TestCase. It will
    # include tests that tell you whether your object is fully compliant,
    # or if not, which aspects of the API are not implemented.
    #
    # Note an object is not required to implement all APIs in order to work
    # with Action Pack. This module only intends to provide guidance in case
    # you want all features out of the box.
    #
    # These tests do not attempt to determine the semantic correctness of the
    # returned values. For instance, you could implement <tt>valid?</tt> to
    # always return +true+, and the tests would pass. It is up to you to ensure
    # that the values are semantically meaningful.
    #
    # Objects you pass in are expected to return a compliant object from a call
    # to <tt>to_model</tt>. It is perfectly fine for <tt>to_model</tt> to return
    # +self+.
    module Tests

      # == Responds to <tt>to_key</tt>
      #
      # Returns an Enumerable of all (primary) key attributes
      # or nil if <tt>model.persisted?</tt> is false. This is used by
      # <tt>dom_id</tt> to generate unique ids for the object.
      def test_to_key
        assert model.respond_to?(:to_key), "The model should respond to to_key"
        def model.persisted?() false end
        assert model.to_key.nil?, "to_key should return nil when `persisted?` returns false"
      end

      # == Responds to <tt>to_param</tt>
      #
      # Returns a string representing the object's key suitable for use in URLs
      # or +nil+ if <tt>model.persisted?</tt> is +false+.
      #
      # Implementers can decide to either raise an exception or provide a
      # default in case the record uses a composite primary key. There are no
      # tests for this behavior in lint because it doesn't make sense to force
      # any of the possible implementation strategies on the implementer.
      # However, if the resource is not persisted?, then <tt>to_param</tt>
      # should always return +nil+.
      def test_to_param
        assert model.respond_to?(:to_param), "The model should respond to to_param"
        def model.to_key() [1] end
        def model.persisted?() false end
        assert model.to_param.nil?, "to_param should return nil when `persisted?` returns false"
      end

      # == Responds to <tt>to_partial_path</tt>
      #
      # Returns a string giving a relative path. This is used for looking up
      # partials. For example, a BlogPost model might return "blog_posts/blog_post"
      def test_to_partial_path
        assert model.respond_to?(:to_partial_path), "The model should respond to to_partial_path"
        assert_kind_of String, model.to_partial_path
      end

      # == Responds to <tt>persisted?</tt>
      #
      # Returns a boolean that specifies whether the object has been persisted
      # yet. This is used when calculating the URL for an object. If the object
      # is not persisted, a form for that object, for instance, will route to
      # the create action. If it is persisted, a form for the object will routes
      # to the update action.
      def test_persisted?
        assert model.respond_to?(:persisted?), "The model should respond to persisted?"
        assert_boolean model.persisted?, "persisted?"
      end

      # == \Naming
      #
      # Model.model_name and Model#model_name must return a string with some
      # convenience methods: # <tt>:human</tt>, <tt>:singular</tt> and
      # <tt>:plural</tt>. Check ActiveModel::Naming for more information.
      def test_model_naming
        assert model.class.respond_to?(:model_name), "The model class should respond to model_name"
        model_name = model.class.model_name
        assert model_name.respond_to?(:to_str)
        assert model_name.human.respond_to?(:to_str)
        assert model_name.singular.respond_to?(:to_str)
        assert model_name.plural.respond_to?(:to_str)

        assert model.respond_to?(:model_name), "The model instance should respond to model_name"
        assert_equal model.model_name, model.class.model_name
      end

      # == \Errors Testing
      #
      # Returns an object that implements [](attribute) defined which returns an
      # Array of Strings that are the errors for the attribute in question.
      # If localization is used, the Strings should be localized for the current
      # locale. If no error is present, this method should return an empty Array.
      def test_errors_aref
        assert model.respond_to?(:errors), "The model should respond to errors"
        assert model.errors[:hello].is_a?(Array), "errors#[] should return an Array"
      end

      private
        def model
          assert @model.respond_to?(:to_model), "The object should respond to to_model"
          @model.to_model
        end

        def assert_boolean(result, name)
          assert result == true || result == false, "#{name} should be a boolean"
        end
    end
  end
end
