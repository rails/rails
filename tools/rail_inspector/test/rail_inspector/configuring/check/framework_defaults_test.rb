# frozen_string_literal: true

require "test_helper"
require "rail_inspector/configuring"

class FrameworkDefaultsTest < ActiveSupport::TestCase
  def test_identifies_self_when_file_uses_config
    defaults = {
      "8.0" => {
        "action_dispatch.strict_freshness" => "true",
        "Regexp.timeout" => "1"
      },
      "8.1" => {
        "self.yjit" => "!Rails.env.local?",
        "action_controller.escape_json_responses" => "false",
      }
    }

    check(defaults, <<~DOC).check
      #### Default Values for Target Version 8.1

      - [`config.action_controller.escape_json_responses`](#config-action-controller-escape-json-responses): `false`
      - [`config.yjit`](#config-yjit): `!Rails.env.local?`

      #### Default Values for Target Version 8.0

      - [`Regexp.timeout`](#regexp-timeout): `1`
      - [`config.action_dispatch.strict_freshness`](#config-action-dispatch-strict-freshness): `true`
    DOC

    assert_empty checker.errors
  end

  def test_post_release
    defaults = {
      "8.0" => {
        "Regexp.timeout" => "1"
      },
      "8.1" => {},
    }

    check(defaults, <<~DOC).check
      #### Default Values for Target Version 8.1

      #### Default Values for Target Version 8.0

      - [`Regexp.timeout`](#regexp-timeout): `1`
    DOC

    assert_empty checker.errors
  end

  private
    def check(defaults, doc)
      @check ||= RailInspector::Configuring::Check::FrameworkDefaults.new(checker, defaults, doc)
    end

    def checker
      @checker ||= RailInspector::Configuring.new("../..")
    end
end
