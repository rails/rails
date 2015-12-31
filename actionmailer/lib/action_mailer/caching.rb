require 'action_dispatch/caching'

module ActionMailer
  module Caching
    extend ActiveSupport::Autoload
    extend ActiveSupport::Concern
    included do
      include ActionDispatch::Caching
    end

    def instrument_payload(key)
      {
        mailer: mailer_name,
        key: key
      }
    end

    def instrument_name
      "action_mailer"
    end
  end
end
