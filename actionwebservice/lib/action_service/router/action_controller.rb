module ActionService # :nodoc:
  module Router # :nodoc:
    module ActionController # :nodoc:
      def self.append_features(base) # :nodoc:
        base.add_web_service_api_callback do |container_class, api|
          if container_class.web_service_dispatching_mode == :direct
            container_class.class_eval <<-EOS
              def api
                process_action_service_request
              end
            EOS
          end
        end
        base.add_web_service_definition_callback do |klass, name, info|
          if klass.web_service_dispatching_mode == :delegated
            klass.class_eval <<-EOS
              def #{name}
                process_action_service_request
              end
            EOS
          end
        end
        base.send(:include, ActionService::Router::ActionController::InstanceMethods)
      end

      module InstanceMethods # :nodoc:
        private
          def process_action_service_request
            protocol_request = nil
            begin
              begin
                protocol_request = probe_request_protocol(self.request)
              rescue Exception => e
                unless logger.nil?
                  logger.error "Invalid request: #{e.message}"
                  logger.error self.request.raw_post
                end
                raise
              end
              if protocol_request
                log_request(protocol_request)
                protocol_response = dispatch_web_service_request(protocol_request)
                log_response(protocol_response)
                response_options = {
                  :type        => protocol_response.content_type,
                  :disposition => 'inline'
                }
                send_data(protocol_response.raw_body, response_options)
              else
                logger.fatal "Invalid Action Service service or method requested" unless logger.nil?
                render_text 'Internal protocol error', "500 Invalid service/method"
              end
            rescue Exception => e
              log_error e unless logger.nil?
              exc_response = nil
              case web_service_dispatching_mode
              when :direct
                if self.class.web_service_exception_reporting
                  exc_response = protocol_request.protocol.marshal_exception(e)
                end
              when :delegated
                web_service = web_service_object(protocol_request.service_name) rescue nil
                if web_service && web_service.class.web_service_exception_reporting
                  exc_response = protocol_request.protocol.marshal_exception(e) rescue nil
                end
              end
              if exc_response
                response_options = {
                  :type        => exc_response.content_type,
                  :disposition => 'inline'
                }
                log_response exc_response
                send_data(exc_response.raw_body, response_options)
              else
                render_text 'Internal protocol error', "500 #{e.message}"
              end
            end
          end

          def log_request(protocol_request)
            unless logger.nil?
              web_service_name = protocol_request.web_service_name
              method_name = protocol_request.public_method_name
              logger.info "\nProcessing Action Service Request: #{web_service_name}##{method_name}"
              logger.info "Raw Request Body:"
              logger.info protocol_request.raw_body
            end
          end

          def log_response(protocol_response)
            unless logger.nil?
              logger.info "\nRaw Response Body:"
              logger.info protocol_response.raw_body
            end
          end
      end
    end
  end
end
