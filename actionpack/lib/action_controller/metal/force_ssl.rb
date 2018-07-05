# frozen_string_literal: true

require "active_support/core_ext/hash/except"
require "active_support/core_ext/hash/slice"

module ActionController
  # This module is deprecated in favor of +config.force_ssl+ in your environment
  # config file. This will ensure all communication to non-whitelisted endpoints
  # served by your application occurs over HTTPS.
  module ForceSSL # :nodoc:
    extend ActiveSupport::Concern
    include AbstractController::Callbacks

    ACTION_OPTIONS = [:only, :except, :if, :unless]
    URL_OPTIONS = [:protocol, :host, :domain, :subdomain, :port, :path]
    REDIRECT_OPTIONS = [:status, :flash, :alert, :notice]

    module ClassMethods # :nodoc:
      def force_ssl(options = {})
        ActiveSupport::Deprecation.warn(<<-MESSAGE.squish)
          Controller-level `force_ssl` is deprecated and will be removed from
          Rails 6.1. Please enable `config.force_ssl` in your environment
          configuration to enable the ActionDispatch::SSL middleware to more
          fully enforce that your application communicate over HTTPS. If needed,
          you can use `config.ssl_options` to exempt matching endpoints from
          being redirected to HTTPS.
        MESSAGE

        action_options = options.slice(*ACTION_OPTIONS)
        redirect_options = options.except(*ACTION_OPTIONS)
        before_action(action_options) do
          force_ssl_redirect(redirect_options)
        end
      end
    end

    def force_ssl_redirect(host_or_options = nil)
      unless request.ssl?
        options = {
          protocol: "https://",
          host: request.host,
          path: request.fullpath,
          status: :moved_permanently
        }

        if host_or_options.is_a?(Hash)
          options.merge!(host_or_options)
        elsif host_or_options
          options[:host] = host_or_options
        end

        secure_url = ActionDispatch::Http::URL.url_for(options.slice(*URL_OPTIONS))
        flash.keep if respond_to?(:flash) && request.respond_to?(:flash)
        redirect_to secure_url, options.slice(*REDIRECT_OPTIONS)
      end
    end
  end
end
