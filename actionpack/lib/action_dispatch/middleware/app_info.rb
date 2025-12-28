# frozen_string_literal: true

module ActionDispatch
  # Middleware that adds application version and environment information to response headers.
  # This helps with debugging, deployment verification, and monitoring.
  #
  # The middleware can be configured through Rails.application.config.app_version:
  #
  #   config.app_version.enabled = true  # Enable/disable the middleware
  #   config.app_version.add_headers = true  # Add version headers to responses
  #   config.app_version.include_revision = -> { Rails.env.local? }  # Include git revision
  #
  # By default, it adds the following headers:
  # * X-App-Version: The application version
  # * X-App-Environment: The current environment
  #
  class AppInfo
    def initialize(app, app_version_config = {})
      @app = app
      @config = app_version_config
      @version_header = @config[:version_header] || "X-App-Version"
      @environment_header = @config[:environment_header] || "X-App-Environment"
    end

    def call(env)
      status, headers, response = @app.call(env)
      headers[@version_header] = version_string
      headers[@environment_header] = Rails.application.app_environment.to_s
      [status, headers, response]
    end

    private
      def version_string
        version = Rails.application.version
        include_revision = @config[:include_revision]

        should_include_revision = case include_revision
        when Proc
          include_revision.call
        when true, false
          include_revision
        else
          Rails.env.local?
        end

        version.full(show_revision: should_include_revision)
      end
  end
end
