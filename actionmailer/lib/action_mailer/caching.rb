require 'active_support/descendants_tracker'

module ActionMailer
  module Caching
    extend ActiveSupport::Concern

    included do
      mattr_accessor :perform_caching, instance_writer: false
    end

    def perform_caching
      Base.perform_caching
    end

    def controller_name
      "ActionMailer"
    end
  end
end
