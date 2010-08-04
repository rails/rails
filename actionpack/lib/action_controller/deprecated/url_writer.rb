module ActionController
  module UrlWriter
    def self.included(klass)
      ActiveSupport::Deprecation.warn "include ActionController::UrlWriter is deprecated. Instead, " \
                                      "include Rails.application.routes.url_helpers"
      klass.class_eval { include Rails.application.routes.url_helpers }
    end
  end

  class UrlRewriter
    def initialize(*)
    end
  end
end
