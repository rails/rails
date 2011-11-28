require 'active_support/core_ext/hash/conversions'
require 'action_dispatch/http/request'
require 'active_support/core_ext/hash/indifferent_access'

module ActionDispatch
  class ParamsParser
    DEFAULT_PARSERS = {
      Mime::XML => :xml_simple,
      Mime::JSON => :json
    }

    def initialize(app, parsers = {})
      @app, @parsers = app, DEFAULT_PARSERS.merge(parsers)
    end

    def call(env)
      if params = parse_formatted_parameters(env)
        env["action_dispatch.request.request_parameters"] = params
      end

      @app.call(env)
    end

    private
      def parse_formatted_parameters(env)
        request = Request.new(env)

        return false if request.content_length.zero?

        mime_type = content_type_from_legacy_post_data_format_header(env) ||
          request.content_mime_type

        strategy = @parsers[mime_type]

        return false unless strategy

        case strategy
        when Proc
          strategy.call(request.raw_post)
        when :xml_simple, :xml_node
          data = Hash.from_xml(request.body.read) || {}
          request.body.rewind if request.body.respond_to?(:rewind)
          data.with_indifferent_access
        when :yaml
          YAML.load(request.raw_post)
        when :json
          data = ActiveSupport::JSON.decode(request.body)
          request.body.rewind if request.body.respond_to?(:rewind)
          data = {:_json => data} unless data.is_a?(Hash)
          data.with_indifferent_access
        else
          false
        end
      rescue Exception => e # YAML, XML or Ruby code block errors
        logger(env).debug "Error occurred while parsing request parameters.\nContents:\n\n#{request.raw_post}"

        raise e
      end

      def content_type_from_legacy_post_data_format_header(env)
        if x_post_format = env['HTTP_X_POST_DATA_FORMAT']
          case x_post_format.to_s.downcase
          when 'yaml' then return Mime::YAML
          when 'xml'  then return Mime::XML
          end
        end

        nil
      end

      def logger(env)
        env['action_dispatch.logger'] || Logger.new($stderr)
      end
  end
end
