module ActionService # :nodoc:
  module Router # :nodoc:
    module ActionController # :nodoc:
      def self.append_features(base) # :nodoc:
        base.add_service_api_callback do |container_class, api|
          if container_class.service_dispatching_mode == :direct && !container_class.method_defined?(:api)
            container_class.class_eval <<-EOS
              def api
                process_action_service_request
              end
            EOS
          end
        end
        base.add_service_definition_callback do |klass, name, info|
          if klass.service_dispatching_mode == :delegated
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
                logger.error "Invalid request: #{e.message}"
                logger.error self.request.raw_post
                raise
              end
              if protocol_request
                log_request(protocol_request)
                protocol_response = dispatch_service_request(protocol_request)
                log_response(protocol_response)
                response_options = {
                  :type        => protocol_response.content_type,
                  :disposition => 'inline'
                }
                send_data(protocol_response.raw_body, response_options)
              else
                logger.fatal "Invalid Action Service service or method requested"
                render_text 'Internal protocol error', "500 Invalid service/method"
              end
            rescue Exception => e
              log_error e unless logger.nil?
              exc_response = nil
              case service_dispatching_mode
              when :direct
                if self.class.service_exception_reporting
                  exc_response = protocol_request.protocol.marshal_exception(e)
                end
              when :delegated
                service_object = service_object(protocol_request.service_name) rescue nil
                if service_object && service_object.class.service_exception_reporting
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
              service_name = protocol_request.service_name
              method_name = protocol_request.public_method_name
              logger.info "\nProcessing Action Service Request: #{service_name}##{method_name}"
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
