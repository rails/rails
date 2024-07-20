# frozen_string_literal: true

module ActiveJob
  module TimezonesAndTranslation # :nodoc:
    extend ActiveSupport::Concern

    included do
      def perform_now
        I18n.with_locale(locale) do
          Time.use_zone(timezone) { super }
        end
      end
    end
  end
end
