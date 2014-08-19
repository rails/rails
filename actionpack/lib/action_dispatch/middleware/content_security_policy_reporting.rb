module ActionDispatch
  class ContentSecurityPolicyReporting
    # Content Security Policy Reporting Middleware
    # In order to let this middleware working, user should do the following two setting:
    #
    # 1. set config.content_security_policy_reporting = true, so Rails can load this middleware properly
    # 2. set report_uri in CSP policy, so browser can send violation report to the server
    #      content_security_policy.enforce do |csp|
    #        csp.report_uri = '/csp_reporter'
    #      end
    #
    # This middleware will log the CSP violation reports, and publish an event 'report.content_security_policy'.
    # So user can subscribe to this event and do whatever they want to do: store at database, send by email, or
    # send to external applications like New Relic
    #
    # The code sample to subscribe to this event:
    #
    # ActiveSupport::Notifications.subscribe "report.content_security_policy" do |name, start, finish, id, payload|
    #    send_to_my_email payload[:report]
    # end
    #
    def initialize(app)
      @app = app
    end

    def call(env)
      req = Rack::Request.new(env)
      if req.content_type == "application/csp-report"
         report = req.body.read
         instrument(report)
         logger(report)
      end
      status, headers, body = @app.call(env)
      [status, headers, body]
    end

    private
      def instrument(data)
        ActiveSupport::Notifications.instrument("report.content_security_policy", report: data)
      end

      def logger(data)
        Rails.logger.warn data
      end
  end
end