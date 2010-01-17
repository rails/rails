module ActionController
  module UrlFor
    extend ActiveSupport::Concern

    include AbstractController::UrlFor
    include ActionController::RackDelegation

  protected

    def _url_rewriter
      return ActionController::UrlRewriter unless request
      @_url_rewriter ||= ActionController::UrlRewriter.new(request, params)
    end
  end
end
