# frozen_string_literal: true

require "abstract_unit"

class IntegrationController < ActionController::Base
  def yaml_params
    render plain: params.to_yaml
  end

  def permit_params
    params.permit(
      key1: {}
    )

    render plain: "Home"
  end
end

class ActionControllerParametersIntegrationTest < ActionController::TestCase
  tests IntegrationController

  test "parameters can be serialized as YAML" do
    post :yaml_params, params: { person: { name: "Mjallo!" } }
    expected = <<~YAML
--- !ruby/object:ActionController::Parameters
parameters: !ruby/hash:ActiveSupport::HashWithIndifferentAccess
  person: !ruby/hash:ActiveSupport::HashWithIndifferentAccess
    name: Mjallo!
  controller: integration
  action: yaml_params
permitted: false
    YAML
    assert_equal expected, response.body
  end

  # Ensure no deprecation warning from comparing AC::Parameters against Hash
  # See https://github.com/rails/rails/issues/44940
  test "identical arrays can be permitted" do
    params = {
      key1: {
        a: [{ same_key: { c: 1 } }],
        b: [{ same_key: { c: 1 } }]
      }
    }

    assert_not_deprecated(ActionController.deprecator) do
      post :permit_params, params: params
    end
    assert_response :ok
  end
end
