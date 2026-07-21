# frozen_string_literal: true

# :markup: markdown

module ActionController # :nodoc:
  # # Action Controller Current Time Zone
  #
  # Sets the time zone for the duration of a request using a callable to
  # determine the time zone. A common pattern is reading from a browser cookie
  # set via JavaScript:
  #
  #     document.cookie = `time_zone=${Intl.DateTimeFormat().resolvedOptions().timeZone}`
  #
  # Include this module and call `set_current_time_zone_from` with a callable:
  #
  #     class ApplicationController < ActionController::Base
  #       include ActionController::CurrentTimeZone
  #       set_current_time_zone_from -> { cookies[:time_zone] }
  #     end
  #
  # The callable is evaluated in the context of each request's controller
  # instance, so it has access to cookies, params, session, and any controller
  # methods.
  module CurrentTimeZone
    extend ActiveSupport::Concern

    class_methods do
      def set_current_time_zone_from(callable)
        around_action do |controller, action|
          if (zone = Time.find_zone(controller.instance_exec(&callable)))
            Time.use_zone(zone) { action.call }
          else
            action.call
          end
        end
      end
    end
  end
end
