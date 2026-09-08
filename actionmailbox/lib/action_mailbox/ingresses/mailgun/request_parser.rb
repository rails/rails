# frozen_string_literal: true

require "rack"
require "stringio"

module ActionMailbox
  module Ingresses
    module Mailgun
      class RequestParser
        PATH = "/rails/action_mailbox/mailgun/inbound_emails/mime"
        CONTENT_TYPE = "application/x-www-form-urlencoded"

        def initialize(app, bytesize_limit:)
          @app = app
          @bytesize_limit = bytesize_limit
          @query_parser = Rack::QueryParser.make_default(
            Rack::Utils.default_query_parser.param_depth_limit,
            bytesize_limit: bytesize_limit
          )
        end

        def call(env)
          if mailgun_request?(env)
            read_limit = @bytesize_limit ? @bytesize_limit + 2 : nil
            form_vars = env.fetch("rack.input").read(read_limit) || ""
            form_vars.slice!(-1) if form_vars.end_with?("\0")

            env["rack.input"] = StringIO.new(form_vars)
            env["rack.request.form_vars"] = form_vars
            env["rack.request.form_pairs"] = @query_parser.parse_query_pairs(form_vars, "&")
          end

          @app.call(env)
        end

        private
          def mailgun_request?(env)
            env["REQUEST_METHOD"] == "POST" &&
              env["PATH_INFO"] == PATH &&
              Rack::MediaType.type(env["CONTENT_TYPE"]) == CONTENT_TYPE
          end
      end
    end
  end
end
