# frozen_string_literal: true

require "active_support/error_reporter"

module ActiveJob
  module ErrorReporter
    extend ActiveSupport::Concern

    included do
      ##
      # Accepts an error reporter
      cattr_accessor :error_reporter, default: ActiveSupport.error_reporter
    end
  end
end
