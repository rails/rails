require 'action_dispatch/caching'

module ActionMailer
  module Caching
    extend ActiveSupport::Autoload
    extend ActiveSupport::Concern
    included do
      include ActionDispatch::Caching
    end

    def perform_caching
      Base.perform_caching
    end

    def controller_name
      "ActionMailer"
    end
  end
end
