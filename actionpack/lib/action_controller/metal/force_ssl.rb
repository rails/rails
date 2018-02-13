# frozen_string_literal: true

require "active_support/core_ext/hash/except"
require "active_support/core_ext/hash/slice"

module ActionController
  # This module provides a method which will redirect the browser to use the secured HTTPS
  # protocol. This will ensure that users' sensitive information will be
  # transferred safely over the internet. You _should_ always force the browser
  # to use HTTPS when you're transferring sensitive information such as
  # user authentication, account information, or credit card information.
  #
  # Note that if you are really concerned about your application security,
  # you might consider using +config.force_ssl+ in your config file instead.
  # That will ensure all the data is transferred via HTTPS, and will
  # prevent the user from getting their session hijacked when accessing the
  # site over unsecured HTTP protocol.
  module ForceSSL
    extend ActiveSupport::Concern
    include AbstractController::Callbacks

    ACTION_OPTIONS = [:only, :except, :if, :unless]
    URL_OPTIONS = [:protocol, :host, :domain, :subdomain, :port, :path]
    REDIRECT_OPTIONS = [:status, :flash, :alert, :notice]

    module ClassMethods
      # Force the request to this particular controller or specified actions to be
      # through the HTTPS protocol.
      #
      # If you need to disable this for any reason (e.g. development) then you can use
      # an +:if+ or +:unless+ condition.
      #
      #     class AccountsController < ApplicationController
      #       force_ssl if: :ssl_configured?
      #
      #       def ssl_configured?
      #         !Rails.env.development?
      #       end
      #     end
      #
      # ==== URL Options
      # You can pass any of the following options to affect the redirect URL
      # * <tt>host</tt>       - Redirect to a different host name
      # * <tt>subdomain</tt>  - Redirect to a different subdomain
      # * <tt>domain</tt>     - Redirect to a different domain
      # * <tt>port</tt>       - Redirect to a non-standard port
      # * <tt>path</tt>       - Redirect to a different path
      #
      # ==== Redirect Options
      # You can pass any of the following options to affect the redirect status and response
      # * <tt>status</tt>     - Redirect with a custom status (default is 301 Moved Permanently)
      # * <tt>flash</tt>      - Set a flash message when redirecting
      # * <tt>alert</tt>      - Set an alert message when redirecting
      # * <tt>notice</tt>     - Set a notice message when redirecting
      #
      # ==== Action Options
      # You can pass any of the following options to affect the before_action callback
      # * <tt>only</tt>       - The callback should be run only for this action
      # * <tt>except</tt>     - The callback should be run for all actions except this action
      # * <tt>if</tt>         - A symbol naming an instance method or a proc; the
      #   callback will be called only when it returns a true value.
      # * <tt>unless</tt>     - A symbol naming an instance method or a proc; the
      #   callback will be called only when it returns a false value.
      def force_ssl(options = {})
        action_options = options.slice(*ACTION_OPTIONS)
        redirect_options = options.except(*ACTION_OPTIONS)
        before_action(action_options) do
          force_ssl_redirect(redirect_options)
        end
      end
    end

    # Redirect the existing request to use the HTTPS protocol.
    #
    # ==== Parameters
    # * <tt>host_or_options</tt> - Either a host name or any of the URL and
    #   redirect options available to the <tt>force_ssl</tt> method.
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
