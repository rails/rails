# frozen_string_literal: true

require "abstract_unit"

class IntegrationController < ActionController::Base
  def yaml_params
    render plain: params.to_yaml
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
end
