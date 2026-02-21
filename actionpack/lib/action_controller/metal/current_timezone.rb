# frozen_string_literal: true

# :markup: markdown

module ActionController # :nodoc:
  # # Action Controller Current Timezone
  #
  # Sets the timezone for the duration of a request based on a `timezone` browser
  # cookie. This allows the application to render time values in the user's local
  # timezone when the cookie has been set, typically via JavaScript on the client:
  #
  #     document.cookie = `timezone=${Intl.DateTimeFormat().resolvedOptions().timeZone}`
  #
  # Include this module in any controller to opt into this behavior:
  #
  #     class ApplicationController < ActionController::Base
  #       include ActionController::CurrentTimezone
  #     end
  #
  # The cookie name defaults to `:timezone` but can be changed at the class level:
  #
  #     class ApplicationController < ActionController::Base
  #       include ActionController::CurrentTimezone
  #       self.timezone_cookie_name = :user_timezone
  #     end
  #
  # The resolved timezone is also exposed as a helper method (`timezone_from_cookie`)
  # and included in the ETag calculation so that timezone-dependent pages are cached
  # separately per timezone.
  module CurrentTimezone
    extend ActiveSupport::Concern

    included do
      class_attribute :timezone_cookie_name, default: :timezone, instance_writer: false

      around_action :set_current_timezone

      helper_method :timezone_from_cookie

      etag { timezone_from_cookie }
    end

    private
      def set_current_timezone
        if (zone = timezone_from_cookie)
          Time.use_zone(zone) { yield }
        else
          yield
        end
      end

      def timezone_from_cookie
        @timezone_from_cookie ||= begin
          timezone = cookies[timezone_cookie_name]
          ActiveSupport::TimeZone[timezone] if timezone.present?
        end
      end
  end
end
