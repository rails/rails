# frozen_string_literal: true

require "isolation/abstract_unit"

module ApplicationTests
  class PermissionPolicyTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation

    def setup
      build_app
    end

    def teardown
      teardown_app
    end

    test "overriding permissions_policy raises if no global policy configured" do
      make_basic_app
      app.config.action_dispatch.show_exceptions = :none

      class ::OmgController < ActionController::Base
        permissions_policy do |f|
          f.gyroscope :none
        end

        def index
          head :ok
        end
      end

      assert_raises RuntimeError, match: /Cannot override permissions_policy/ do
        get "/"
      end
    end
  end
end
