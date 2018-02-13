# frozen_string_literal: true

require "abstract_unit"

module Admin; class User; end; end

module ParamsWrapperTestHelp
  def with_default_wrapper_options(&block)
    @controller.class._set_wrapper_options(format: [:json])
    @controller.class.inherited(@controller.class)
    yield
  end

  def assert_parameters(expected)
    assert_equal expected, self.class.controller_class.last_parameters
  end
end

class ParamsWrapperTest < ActionController::TestCase
  include ParamsWrapperTestHelp

  class UsersController < ActionController::Base
    class << self
      attr_accessor :last_parameters
    end

    def parse
      self.class.last_parameters = request.params.except(:controller, :action)
      head :ok
    end
  end

  class User
    def self.attribute_names
      []
    end

    def self.stored_attributes
      { settings: [:color, :size] }
    end
  end

  class Person
    def self.attribute_names
      []
    end
  end

  tests UsersController

  def teardown
    UsersController.last_parameters = nil
  end

  def test_filtered_parameters
    with_default_wrapper_options do
      @request.env["CONTENT_TYPE"] = "application/json"
      post :parse, params: { "username" => "sikachu" }
      assert_equal({ "controller" => "params_wrapper_test/users", "action" => "parse", "username" => "sikachu", "user" => { "username" => "sikachu" } }, @request.filtered_parameters)
    end
  end

  def test_derived_name_from_controller
    with_default_wrapper_options do
      @request.env["CONTENT_TYPE"] = "application/json"
      post :parse, params: { "username" => "sikachu" }
      assert_parameters("username" => "sikachu", "user" => { "username" => "sikachu" })
    end
  end

  def test_store_accessors_wrapped
    assert_called(User, :attribute_names, times: 2, returns: ["username"]) do
      with_default_wrapper_options do
        @request.env["CONTENT_TYPE"] = "application/json"
        post :parse, params: { "username" => "sikachu", "color" => "blue", "size" => "large" }
        assert_parameters("username" => "sikachu", "color" => "blue", "size" => "large",
                           "user" => { "username" => "sikachu", "color" => "blue", "size" => "large" })
      end
    end
  end

  def test_specify_wrapper_name
    with_default_wrapper_options do
      UsersController.wrap_parameters :person

      @request.env["CONTENT_TYPE"] = "application/json"
      post :parse, params: { "username" => "sikachu" }
      assert_parameters("username" => "sikachu", "person" => { "username" => "sikachu" })
    end
  end

  def test_specify_wrapper_model
    with_default_wrapper_options do
      UsersController.wrap_parameters Person

      @request.env["CONTENT_TYPE"] = "application/json"
      post :parse, params: { "username" => "sikachu" }
      assert_parameters("username" => "sikachu", "person" => { "username" => "sikachu" })
    end
  end

  def test_specify_include_option
    with_default_wrapper_options do
      UsersController.wrap_parameters include: :username

      @request.env["CONTENT_TYPE"] = "application/json"
      post :parse, params: { "username" => "sikachu", "title" => "Developer" }
      assert_parameters("username" => "sikachu", "title" => "Developer", "user" => { "username" => "sikachu" })
    end
  end

  def test_specify_exclude_option
    with_default_wrapper_options do
      UsersController.wrap_parameters exclude: :title

      @request.env["CONTENT_TYPE"] = "application/json"
      post :parse, params: { "username" => "sikachu", "title" => "Developer" }
      assert_parameters("username" => "sikachu", "title" => "Developer", "user" => { "username" => "sikachu" })
    end
  end

  def test_specify_both_wrapper_name_and_include_option
    with_default_wrapper_options do
      UsersController.wrap_parameters :person, include: :username

      @request.env["CONTENT_TYPE"] = "application/json"
      post :parse, params: { "username" => "sikachu", "title" => "Developer" }
      assert_parameters("username" => "sikachu", "title" => "Developer", "person" => { "username" => "sikachu" })
    end
  end

  def test_not_enabled_format
    with_default_wrapper_options do
      @request.env["CONTENT_TYPE"] = "application/xml"
      post :parse, params: { "username" => "sikachu", "title" => "Developer" }
      assert_parameters("username" => "sikachu", "title" => "Developer")
    end
  end

  def test_wrap_parameters_false
    with_default_wrapper_options do
      UsersController.wrap_parameters false
      @request.env["CONTENT_TYPE"] = "application/json"
      post :parse, params: { "username" => "sikachu", "title" => "Developer" }
      assert_parameters("username" => "sikachu", "title" => "Developer")
    end
  end

  def test_specify_format
    with_default_wrapper_options do
      UsersController.wrap_parameters format: :xml

      @request.env["CONTENT_TYPE"] = "application/xml"
      post :parse, params: { "username" => "sikachu", "title" => "Developer" }
      assert_parameters("username" => "sikachu", "title" => "Developer", "user" => { "username" => "sikachu", "title" => "Developer" })
    end
  end

  def test_not_wrap_reserved_parameters
    with_default_wrapper_options do
      @request.env["CONTENT_TYPE"] = "application/json"
      post :parse, params: { "authenticity_token" => "pwned", "_method" => "put", "utf8" => "&#9731;", "username" => "sikachu" }
      assert_parameters("authenticity_token" => "pwned", "_method" => "put", "utf8" => "&#9731;", "username" => "sikachu", "user" => { "username" => "sikachu" })
    end
  end

  def test_no_double_wrap_if_key_exists
    with_default_wrapper_options do
      @request.env["CONTENT_TYPE"] = "application/json"
      post :parse, params: { "user" => { "username" => "sikachu" } }
      assert_parameters("user" => { "username" => "sikachu" })
    end
  end

  def test_no_double_wrap_if_key_exists_and_value_is_nil
    with_default_wrapper_options do
      @request.env["CONTENT_TYPE"] = "application/json"
      post :parse, params: { "user" => nil }
      assert_parameters("user" => nil)
    end
  end

  def test_nested_params
    with_default_wrapper_options do
      @request.env["CONTENT_TYPE"] = "application/json"
      post :parse, params: { "person" => { "username" => "sikachu" } }
      assert_parameters("person" => { "username" => "sikachu" }, "user" => { "person" => { "username" => "sikachu" } })
    end
  end

  def test_derived_wrapped_keys_from_matching_model
    assert_called(User, :attribute_names, times: 2, returns: ["username"]) do
      with_default_wrapper_options do
        @request.env["CONTENT_TYPE"] = "application/json"
        post :parse, params: { "username" => "sikachu", "title" => "Developer" }
        assert_parameters("username" => "sikachu", "title" => "Developer", "user" => { "username" => "sikachu" })
      end
    end
  end

  def test_derived_wrapped_keys_from_specified_model
    with_default_wrapper_options do
      assert_called(Person, :attribute_names, times: 2, returns: ["username"]) do
        UsersController.wrap_parameters Person

        @request.env["CONTENT_TYPE"] = "application/json"
        post :parse, params: { "username" => "sikachu", "title" => "Developer" }
        assert_parameters("username" => "sikachu", "title" => "Developer", "person" => { "username" => "sikachu" })
      end
    end
  end

  def test_not_wrapping_abstract_model
    with_default_wrapper_options do
      @request.env["CONTENT_TYPE"] = "application/json"
      post :parse, params: { "username" => "sikachu", "title" => "Developer" }
      assert_parameters("username" => "sikachu", "title" => "Developer", "user" => { "username" => "sikachu", "title" => "Developer" })
    end
  end

  def test_preserves_query_string_params
    with_default_wrapper_options do
      @request.env["CONTENT_TYPE"] = "application/json"
      get :parse, params: { "user" => { "username" => "nixon" } }
      assert_parameters(
        "user" => { "username" => "nixon" }
      )
    end
  end

  def test_preserves_query_string_params_in_filtered_params
    with_default_wrapper_options do
      @request.env["CONTENT_TYPE"] = "application/json"
      get :parse, params: { "user" => { "username" => "nixon" } }
      assert_equal({ "controller" => "params_wrapper_test/users", "action" => "parse", "user" => { "username" => "nixon" } }, @request.filtered_parameters)
    end
  end

  def test_empty_parameter_set
    with_default_wrapper_options do
      @request.env["CONTENT_TYPE"] = "application/json"
      post :parse, params: {}
      assert_parameters(
        "user" => {}
      )
    end
  end

  def test_handles_empty_content_type
    with_default_wrapper_options do
      @request.env["CONTENT_TYPE"] = nil
      _controller_class.dispatch(:parse, @request, @response)

      assert_equal 200, @response.status
      assert_equal "", @response.body
    end
  end

  def test_derived_wrapped_keys_from_nested_attributes
    def User.nested_attributes_options
      { person: {} }
    end

    assert_called(User, :attribute_names, times: 2, returns: ["username"]) do
      with_default_wrapper_options do
        @request.env["CONTENT_TYPE"] = "application/json"
        post :parse, params: { "username" => "sikachu", "person_attributes" => { "title" => "Developer" } }
        assert_parameters("username" => "sikachu", "person_attributes" => { "title" => "Developer" }, "user" => { "username" => "sikachu", "person_attributes" => { "title" => "Developer" } })
      end
    end
  end
end

class NamespacedParamsWrapperTest < ActionController::TestCase
  include ParamsWrapperTestHelp

  module Admin
    module Users
      class UsersController < ActionController::Base
        class << self
          attr_accessor :last_parameters
        end

        def parse
          self.class.last_parameters = request.params.except(:controller, :action)
          head :ok
        end
      end
    end
  end

  class SampleOne
    def self.attribute_names
      ["username"]
    end
  end

  class SampleTwo
    def self.attribute_names
      ["title"]
    end
  end

  tests Admin::Users::UsersController

  def teardown
    Admin::Users::UsersController.last_parameters = nil
  end

  def test_derived_name_from_controller
    with_default_wrapper_options do
      @request.env["CONTENT_TYPE"] = "application/json"
      post :parse, params: { "username" => "sikachu" }
      assert_parameters("username" => "sikachu", "user" => { "username" => "sikachu" })
    end
  end

  def test_namespace_lookup_from_model
    Admin.const_set(:User, Class.new(SampleOne))
    begin
      with_default_wrapper_options do
        @request.env["CONTENT_TYPE"] = "application/json"
        post :parse, params: { "username" => "sikachu", "title" => "Developer" }
        assert_parameters("username" => "sikachu", "title" => "Developer", "user" => { "username" => "sikachu" })
      end
    ensure
      Admin.send :remove_const, :User
    end
  end

  def test_hierarchy_namespace_lookup_from_model
    Object.const_set(:User, Class.new(SampleTwo))
    begin
      with_default_wrapper_options do
        @request.env["CONTENT_TYPE"] = "application/json"
        post :parse, params: { "username" => "sikachu", "title" => "Developer" }
        assert_parameters("username" => "sikachu", "title" => "Developer", "user" => { "title" => "Developer" })
      end
    ensure
      Object.send :remove_const, :User
    end
  end
end

class AnonymousControllerParamsWrapperTest < ActionController::TestCase
  include ParamsWrapperTestHelp

  tests(Class.new(ActionController::Base) do
    class << self
      attr_accessor :last_parameters
    end

    def parse
      self.class.last_parameters = request.params.except(:controller, :action)
      head :ok
    end
  end)

  def test_does_not_implicitly_wrap_params
    with_default_wrapper_options do
      @request.env["CONTENT_TYPE"] = "application/json"
      post :parse, params: { "username" => "sikachu" }
      assert_parameters("username" => "sikachu")
    end
  end

  def test_does_wrap_params_if_name_provided
    with_default_wrapper_options do
      @controller.class.wrap_parameters(name: "guest")
      @request.env["CONTENT_TYPE"] = "application/json"
      post :parse, params: { "username" => "sikachu" }
      assert_parameters("username" => "sikachu", "guest" => { "username" => "sikachu" })
    end
  end
end

class IrregularInflectionParamsWrapperTest < ActionController::TestCase
  include ParamsWrapperTestHelp

  class ParamswrappernewsItem
    def self.attribute_names
      ["test_attr"]
    end
  end

  class ParamswrappernewsController < ActionController::Base
    class << self
      attr_accessor :last_parameters
    end

    def parse
      self.class.last_parameters = request.params.except(:controller, :action)
      head :ok
    end
  end

  tests ParamswrappernewsController

  def test_uses_model_attribute_names_with_irregular_inflection
    with_dup do
      ActiveSupport::Inflector.inflections do |inflect|
        inflect.irregular "paramswrappernews_item", "paramswrappernews"
      end

      with_default_wrapper_options do
        @request.env["CONTENT_TYPE"] = "application/json"
        post :parse, params: { "username" => "sikachu", "test_attr" => "test_value" }
        assert_parameters("username" => "sikachu", "test_attr" => "test_value", "paramswrappernews_item" => { "test_attr" => "test_value" })
      end
    end
  end

  private

    def with_dup
      original = ActiveSupport::Inflector::Inflections.instance_variable_get(:@__instance__)[:en]
      ActiveSupport::Inflector::Inflections.instance_variable_set(:@__instance__, en: original.dup)
      yield
    ensure
      ActiveSupport::Inflector::Inflections.instance_variable_set(:@__instance__, en: original)
    end
end
