require 'xmlrpc/parser'
require 'xmlrpc/create'
require 'xmlrpc/config'
require 'xmlrpc/utils'
require 'singleton'

module XMLRPC # :nodoc:
  class XmlRpcHelper # :nodoc:
    include Singleton
    include ParserWriterChooseMixin

    def parse_method_call(message)
      parser().parseMethodCall(message)
    end

    def create_method_response(successful, return_value)
      create().methodResponse(successful, return_value)
    end
  end
end

module ActionService # :nodoc:
  module Protocol # :nodoc:
    module XmlRpc # :nodoc:
      def self.append_features(base) # :nodoc:
        super
        base.register_protocol(BodyOnly, XmlRpcProtocol)
      end

      class XmlRpcProtocol < AbstractProtocol # :nodoc:

        public

        def self.create_protocol_request(container_class, action_pack_request)
          helper = XMLRPC::XmlRpcHelper.instance
          service_name = action_pack_request.parameters['action']
          methodname, params = helper.parse_method_call(action_pack_request.raw_post)
          methodname.gsub!(/^[^\.]+\./, '') unless methodname =~ /^system\./ # XXX
          protocol = XmlRpcProtocol.new(container_class)
          content_type = action_pack_request.env['HTTP_CONTENT_TYPE']
          content_type ||= 'text/xml'
          request = ProtocolRequest.new(protocol,
                                        action_pack_request.raw_post,
                                        service_name.to_sym,
                                        methodname,
                                        content_type,
                                        :xmlrpc_values => params)
          request
        rescue
          nil
        end

        def self.create_protocol_client(api, protocol_name, endpoint_uri, options)
          return nil unless protocol_name.to_s.downcase.to_sym == :xmlrpc
          ActionService::Client::XmlRpc.new(api, endpoint_uri, options)
        end

        def initialize(container_class)
          super(container_class)
          container_class.write_inheritable_hash('default_system_methods', XmlRpcProtocol => method(:xmlrpc_default_system_handler))
        end

        def unmarshal_request(protocol_request)
          values = protocol_request.options[:xmlrpc_values]
          signature = protocol_request.signature
          if signature
            values = self.class.transform_incoming_method_params(self.class.transform_array_types(signature), values)
            protocol_request.check_parameter_types(values, check_array_types(signature))
            values
          else
            protocol_request.checked? ? [] : values
          end
        end
  
        def marshal_response(protocol_request, return_value)
          helper = XMLRPC::XmlRpcHelper.instance
          signature = protocol_request.return_signature
          if signature
            protocol_request.check_parameter_types([return_value], check_array_types(signature))
            return_value = self.class.transform_return_value(self.class.transform_array_types(signature), return_value)
            raw_response = helper.create_method_response(true, return_value)
          else
            # XML-RPC doesn't have the concept of a void method, nor does it
            # support a nil return value, so return true if we would have returned
            # nil
            if protocol_request.checked?
              raw_response = helper.create_method_response(true, true)
            else
              return_value = true if return_value.nil?
              raw_response = helper.create_method_response(true, return_value)
            end
          end
          ProtocolResponse.new(self, raw_response, 'text/xml')
        end
  
        def marshal_exception(exception)
          helper = XMLRPC::XmlRpcHelper.instance
          exception = XMLRPC::FaultException.new(1, exception.message)
          raw_response = helper.create_method_response(false, exception)
          ProtocolResponse.new(self, raw_response, 'text/xml')
        end

        class << self
          def transform_incoming_method_params(signature, params)
            (1..signature.size).each do |i|
              i -= 1
              params[i] = xmlrpc_to_ruby(params[i], signature[i])
            end
            params
          end

          def transform_return_value(signature, return_value)
            ruby_to_xmlrpc(return_value, signature[0])
          end

          def ruby_to_xmlrpc(param, param_class)
            if param_class.is_a?(XmlRpcArray)
              param.map{|p| ruby_to_xmlrpc(p, param_class.klass)}
            elsif param_class.ancestors.include?(ActiveRecord::Base)
              param.instance_variable_get('@attributes')
            elsif param_class.ancestors.include?(ActionService::Struct)
              struct = {}
              param_class.members.each do |name, klass|
                value = param.send(name)
                next if value.nil?
                struct[name.to_s] = value
              end
              struct
            else
              param
            end
          end

          def xmlrpc_to_ruby(param, param_class)
            if param_class.is_a?(XmlRpcArray)
              param.map{|p| xmlrpc_to_ruby(p, param_class.klass)}
            elsif param_class.ancestors.include?(ActiveRecord::Base)
              raise(ProtocolError, "incoming ActiveRecord::Base types are not allowed")
            elsif param_class.ancestors.include?(ActionService::Struct)
              unless param.is_a?(Hash)
                raise(ProtocolError, "expected parameter to be a Hash")
              end
              new_param = param_class.new
              param_class.members.each do |name, klass|
                new_param.send('%s=' % name.to_s, param[name.to_s])
              end
              new_param
            else
              param
            end
          end

          def transform_array_types(signature)
            signature.map{|x| x.is_a?(Array) ? XmlRpcArray.new(x[0]) : x}
          end
        end
  
        private
          def xmlrpc_default_system_handler(name, service_class, *args)
            case name
            when 'system.listMethods'
              methods = []
              api = service_class.service_api
              api.api_methods.each do |name, info|
                methods << api.public_api_method_name(name)
              end
              methods.sort
            else
              throw :try_default
            end
          end

          def check_array_types(signature)
            signature.map{|x| x.is_a?(Array) ? Array : x}
          end
          
          class XmlRpcArray
            attr :klass
            def initialize(klass)
              @klass = klass
            end
          end
      end

    end
  end
end
