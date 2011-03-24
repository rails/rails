module ActiveModel
  module Lint
    # == Active Model Lint Tests
    #
    # You can test whether an object is compliant with the Active Model API by
    # including <tt>ActiveModel::Lint::Tests</tt> in your TestCase. It will include
    # tests that tell you whether your object is fully compliant, or if not,
    # which aspects of the API are not implemented.
    #
    # These tests do not attempt to determine the semantic correctness of the
    # returned values. For instance, you could implement valid? to always
    # return true, and the tests would pass. It is up to you to ensure that
    # the values are semantically meaningful.
    #
    # Objects you pass in are expected to return a compliant object from a
    # call to to_model. It is perfectly fine for to_model to return self.
    module Tests

      # == Responds to <tt>to_key</tt>
      #
      # Returns an Enumerable of all (primary) key attributes
      # or nil if model.persisted? is false
      def test_to_key
        assert model.respond_to?(:to_key), "The model should respond to to_key"
        def model.persisted?() false end
        assert model.to_key.nil?, "to_key should return nil when `persisted?` returns false"
      end

      # == Responds to <tt>to_param</tt>
      #
      # Returns a string representing the object's key suitable for use in URLs
      # or nil if model.persisted? is false.
      #
      # Implementers can decide to either raise an exception or provide a default
      # in case the record uses a composite primary key. There are no tests for this
      # behavior in lint because it doesn't make sense to force any of the possible
      # implementation strategies on the implementer. However, if the resource is
      # not persisted?, then to_param should always return nil.
      def test_to_param
        assert model.respond_to?(:to_param), "The model should respond to to_param"
        def model.to_key() [1] end
        def model.persisted?() false end
        assert model.to_param.nil?, "to_param should return nil when `persisted?` returns false"
      end

      # == Responds to <tt>valid?</tt>
      #
      # Returns a boolean that specifies whether the object is in a valid or invalid
      # state.
      def test_valid?
        assert model.respond_to?(:valid?), "The model should respond to valid?"
        assert_boolean model.valid?, "valid?"
      end

      # == Responds to <tt>persisted?</tt>
      #
      # Returns a boolean that specifies whether the object has been persisted yet.
      # This is used when calculating the URL for an object. If the object is
      # not persisted, a form for that object, for instance, will be POSTed to the
      # collection. If it is persisted, a form for the object will be PUT to the
      # URL for the object.
      def test_persisted?
        assert model.respond_to?(:persisted?), "The model should respond to persisted?"
        assert_boolean model.persisted?, "persisted?"
      end

      # == Naming
      #
      # Model.model_name must return a string with some convenience methods as
      # :human and :partial_path. Check ActiveModel::Naming for more information.
      #
      def test_model_naming
        assert model.class.respond_to?(:model_name), "The model should respond to model_name"
        model_name = model.class.model_name
        assert_kind_of String, model_name
        assert_kind_of String, model_name.human
        assert_kind_of String, model_name.partial_path
        assert_kind_of String, model_name.singular
        assert_kind_of String, model_name.plural
      end

      # == Errors Testing
      #
      # Returns an object that has :[] and :full_messages defined on it. See below
      # for more details.
      #
      # Returns an Array of Strings that are the errors for the attribute in
      # question. If localization is used, the Strings should be localized
      # for the current locale. If no error is present, this method should
      # return an empty Array.
      def test_errors_aref
        assert model.respond_to?(:errors), "The model should respond to errors"
        assert model.errors[:hello].is_a?(Array), "errors#[] should return an Array"
      end

      # Returns an Array of all error messages for the object. Each message
      # should contain information about the field, if applicable.
      def test_errors_full_messages
        assert model.respond_to?(:errors), "The model should respond to errors"
        assert model.errors.full_messages.is_a?(Array), "errors#full_messages should return an Array"
      end

      private
        def model
          assert @model.respond_to?(:to_model), "The object should respond_to to_model"
          @model.to_model
        end

        def assert_boolean(result, name)
          assert result == true || result == false, "#{name} should be a boolean"
        end
    end
  end
end
