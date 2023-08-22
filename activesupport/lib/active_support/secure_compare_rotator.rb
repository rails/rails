# frozen_string_literal: true

require "active_support/security_utils"
require "active_support/messages/rotator"

module ActiveSupport
  # = Secure Compare Rotator
  #
  # The ActiveSupport::SecureCompareRotator is a wrapper around ActiveSupport::SecurityUtils.secure_compare
  # and allows you to rotate a previously defined value to a new one.
  #
  # It can be used as follow:
  #
  #   rotator = ActiveSupport::SecureCompareRotator.new('new_production_value')
  #   rotator.rotate('previous_production_value')
  #   rotator.secure_compare!('previous_production_value')
  #
  # One real use case example would be to rotate a basic auth credentials:
  #
  #   class MyController < ApplicationController
  #     def authenticate_request
  #       rotator = ActiveSupport::SecureCompareRotator.new('new_password')
  #       rotator.rotate('old_password')
  #
  #       authenticate_or_request_with_http_basic do |username, password|
  #         rotator.secure_compare!(password)
  #       rescue ActiveSupport::SecureCompareRotator::InvalidMatch
  #         false
  #       end
  #     end
  #   end
  class SecureCompareRotator
    include SecurityUtils

    InvalidMatch = Class.new(StandardError)

    def initialize(value, on_rotation: nil)
      @value = value
      @rotate_values = []
      @on_rotation = on_rotation
    end

    def rotate(previous_value)
      @rotate_values << previous_value
    end

    def secure_compare!(other_value, on_rotation: @on_rotation)
      if secure_compare(@value, other_value)
        true
      elsif @rotate_values.any? { |value| secure_compare(value, other_value) }
        on_rotation&.call
        true
      else
        raise InvalidMatch
      end
    end
  end
end
