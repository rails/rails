module ActionController
  # This module provides a method which will redirect browser to use HTTPS
  # protocol. This will ensure that user's sensitive information will be
  # transferred safely over the internet. You _should_ always force browser
  # to use HTTPS when you're transferring sensitive information such as
  # user authentication, account information, or credit card information.
  #
  # Note that if you are really concerned about your application security,
  # you might consider using +config.force_ssl+ in your config file instead.
  # That will ensure all the data transferred via HTTPS protocol and prevent
  # user from getting session hijacked when accessing the site under unsecured
  # HTTP protocol.
  module ForceSSL
    extend ActiveSupport::Concern
    include AbstractController::Callbacks

    module ClassMethods
      # Force the request to this particular controller or specified actions to be
      # under HTTPS protocol.
      #
      # If you need to disable this for any reason (e.g. development) then you can use
      # an +:if+ or +:unless+ condition.
      #
      #     class AccountsController < ApplicationController
      #       force_ssl :if => :ssl_configured?
      #
      #       def ssl_configured?
      #         !Rails.env.development?
      #       end
      #     end
      #
      # ==== Options
      # * <tt>host</tt>   - Redirect to a different host name
      # * <tt>only</tt>   - The callback should be run only for this action
      # * <tt>except</tt>  - The callback should be run for all actions except this action
      # * <tt>if</tt>     - A symbol naming an instance method or a proc; the callback
      #                     will be called only when it returns a true value.
      # * <tt>unless</tt> - A symbol naming an instance method or a proc; the callback
      #                     will be called only when it returns a false value.
      def force_ssl(options = {})
        host = options.delete(:host)
        before_filter(options) do
          force_ssl_redirect(host)
        end
      end
    end

    # Redirect the existing request to use the HTTPS protocol.
    #
    # ==== Parameters
    # * <tt>host</tt> - Redirect to a different host name
    def force_ssl_redirect(host = nil)
      unless request.ssl?
        redirect_options = {:protocol => 'https://', :status => :moved_permanently}
        redirect_options.merge!(:host => host) if host
        redirect_options.merge!(:params => request.query_parameters)
        flash.keep if respond_to?(:flash)
        redirect_to redirect_options
      end
    end
  end
end
