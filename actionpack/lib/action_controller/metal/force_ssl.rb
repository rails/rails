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
      # Note that this method will not be effective on development environment.
      #
      # ==== Options
      # * <tt>only</tt>   - The callback should be run only for this action
      # * <tt>except<tt>  - The callback should be run for all actions except this action
      def force_ssl(options = {})
        host = options.delete(:host)
        before_filter(options) do
          if !request.ssl? && !Rails.env.development?
            redirect_options = {:protocol => 'https://', :status => :moved_permanently}
            redirect_options.merge!(:host => host) if host
            redirect_options.merge!(:params => request.query_parameters)
            redirect_to redirect_options
          end
        end
      end
    end
  end
end
