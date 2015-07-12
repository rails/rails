require 'active_support/core_ext/hash/conversions'
require 'action_dispatch/http/request'
require 'active_support/core_ext/hash/indifferent_access'

module ActionDispatch
  class ParamsParser
    class ParseError < StandardError
      attr_reader :original_exception

      def initialize(message, original_exception)
        super(message)
        @original_exception = original_exception
      end
    end

    DEFAULT_PARSERS = {
      Mime::JSON => lambda { |raw_post|
        data = ActiveSupport::JSON.decode(raw_post)
        data = {:_json => data} unless data.is_a?(Hash)
        Request::Utils.deep_munge(data).with_indifferent_access
      }
    }

    def initialize(app, parsers = {})
      @app, @parsers = app, DEFAULT_PARSERS.merge(parsers)
    end

    def call(env)
      default = env["action_dispatch.request.request_parameters"]
      env["action_dispatch.request.request_parameters"] = parse_formatted_parameters(env, @parsers, default)

      @app.call(env)
    end

    private
      def parse_formatted_parameters(env, parsers, default)
        request = Request.new(env)

        return default if request.content_length.zero?

        strategy = parsers.fetch(request.content_mime_type) { return default }

        strategy.call(request.raw_post)

      rescue => e # JSON or Ruby code block errors
        logger(env).debug "Error occurred while parsing request parameters.\nContents:\n\n#{request.raw_post}"

        raise ParseError.new(e.message, e)
      end

      def logger(env)
        env['action_dispatch.logger'] || ActiveSupport::Logger.new($stderr)
      end
  end
end
