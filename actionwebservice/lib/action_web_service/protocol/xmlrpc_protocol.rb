require 'xmlrpc/marshal'
require 'action_web_service/client/xmlrpc_client'

module XMLRPC # :nodoc:
  class FaultException # :nodoc:
    alias :message :faultString
  end
  
  class Create
    def wrong_type(value)
      if BigDecimal === value
        [true, value.to_f]
      else
        false
      end
    end
  end
end

module ActionWebService # :nodoc:
  module API # :nodoc: 
    class Base # :nodoc:
      def self.xmlrpc_client(endpoint_uri, options={})
        ActionWebService::Client::XmlRpc.new self, endpoint_uri, options
      end
    end
  end

  module Protocol # :nodoc:
    module XmlRpc # :nodoc:
      def self.included(base)
        base.register_protocol(XmlRpcProtocol)
      end
      
      class XmlRpcProtocol < AbstractProtocol # :nodoc:
        def self.create(controller)
          XmlRpcProtocol.new
        end

        def decode_action_pack_request(action_pack_request)
          service_name = action_pack_request.parameters['action']
          decode_request(action_pack_request.raw_post, service_name)
        end

        def decode_request(raw_request, service_name)
          method_name, params = XMLRPC::Marshal.load_call(raw_request)
          Request.new(self, method_name, params, service_name)
        rescue
          return nil
        end

        def encode_request(method_name, params, param_types)
          if param_types
            params = params.dup
            param_types.each_with_index{ |type, i| params[i] = value_to_xmlrpc_wire_format(params[i], type) }
          end
          XMLRPC::Marshal.dump_call(method_name, *params)
        end

        def decode_response(raw_response)
          [nil, XMLRPC::Marshal.load_response(raw_response)]
        end

        def encode_response(method_name, return_value, return_type, protocol_options={})
          if return_value && return_type
            return_value = value_to_xmlrpc_wire_format(return_value, return_type)
          end
          return_value = false if return_value.nil?
          raw_response = XMLRPC::Marshal.dump_response(return_value)
          Response.new(raw_response, 'text/xml', return_value)
        end

        def encode_multicall_response(responses, protocol_options={})
          result = responses.map do |return_value, return_type|
            if return_value && return_type
              return_value = value_to_xmlrpc_wire_format(return_value, return_type) 
              return_value = [return_value] unless return_value.nil?
            end
            return_value = false if return_value.nil?
            return_value
          end
          raw_response = XMLRPC::Marshal.dump_response(result)
          Response.new(raw_response, 'text/xml', result)
        end

        def protocol_client(api, protocol_name, endpoint_uri, options={})
          return nil unless protocol_name == :xmlrpc
          ActionWebService::Client::XmlRpc.new(api, endpoint_uri, options)
        end

        def value_to_xmlrpc_wire_format(value, value_type)
          if value_type.array?
            value.map{ |val| value_to_xmlrpc_wire_format(val, value_type.element_type) }
          else
            if value.is_a?(ActionWebService::Struct)
              struct = {}
              value.class.members.each do |name, type|
                member_value = value[name]
                next if member_value.nil?
                struct[name.to_s] = value_to_xmlrpc_wire_format(member_value, type)
              end
              struct
            elsif value.is_a?(ActiveRecord::Base)
              struct = {}
              value.attributes.each do |key, member_value|
                next if member_value.nil?
                struct[key.to_s] = member_value
              end
              struct
            elsif value.is_a?(ActionWebService::Base64)
              XMLRPC::Base64.new(value)
            elsif value.is_a?(Exception) && !value.is_a?(XMLRPC::FaultException)
              XMLRPC::FaultException.new(2, value.message)
            else
              value
            end
          end
        end
      end
    end
  end
end
