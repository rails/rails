module ActionController
  class ParamsParser
    ActionController::Base.param_parsers[Mime::XML] = :xml_simple
    ActionController::Base.param_parsers[Mime::JSON] = :json

    def initialize(app)
      @app = app
    end

    def call(env)
      if params = parse_formatted_parameters(env)
        env["action_controller.request.request_parameters"] = params
      end

      @app.call(env)
    end

    private
      def parse_formatted_parameters(env)
        request = Request.new(env)

        return false if request.content_length.zero?

        mime_type = content_type_from_legacy_post_data_format_header(env) || request.content_type
        strategy = ActionController::Base.param_parsers[mime_type]

        return false unless strategy

        case strategy
          when Proc
            strategy.call(request.raw_post)
          when :xml_simple, :xml_node
            body = request.raw_post
            body.blank? ? {} : Hash.from_xml(body).with_indifferent_access
          when :yaml
            YAML.load(request.raw_post)
          when :json
            body = request.raw_post
            if body.blank?
              {}
            else
              data = ActiveSupport::JSON.decode(body)
              data = {:_json => data} unless data.is_a?(Hash)
              data.with_indifferent_access
            end
          else
            false
        end
      rescue Exception => e # YAML, XML or Ruby code block errors
        logger.debug "Error occurred while parsing request parameters.\nContents:\n\n#{request.raw_post}"

        raise
          { "body" => request.raw_post,
            "content_type" => request.content_type,
            "content_length" => request.content_length,
            "exception" => "#{e.message} (#{e.class})",
            "backtrace" => e.backtrace }
      end

      def content_type_from_legacy_post_data_format_header(env)
        if x_post_format = env['HTTP_X_POST_DATA_FORMAT']
          case x_post_format.to_s.downcase
            when 'yaml'
              return Mime::YAML
            when 'xml'
              return Mime::XML
          end
        end

        nil
      end

      def logger
        defined?(Rails.logger) ? Rails.logger : Logger.new($stderr)
      end
  end
end
