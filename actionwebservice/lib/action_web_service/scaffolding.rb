require 'ostruct'
require 'uri'
require 'benchmark'

module ActionWebService
  module Scaffolding # :nodoc:
    def self.append_features(base)
      super
      base.extend(ClassMethods)
    end

    # Web service invocation scaffolding provides a way to quickly invoke web service methods in a controller. The
    # generated scaffold actions have default views to let you enter the method parameters and view the
    # results.
    #
    # Example:
    #
    #   class ApiController < ActionController
    #     web_service_scaffold :invoke
    #   end
    #
    # This example generates an +invoke+ action in the +ApiController+ that you can navigate to from
    # your browser, select the API method, enter its parameters, and perform the invocation.
    #
    # If you want to customize the default views, create the following views in "app/views":
    #
    # * <tt>action_name/methods.rhtml</tt>
    # * <tt>action_name/parameters.rhtml</tt>
    # * <tt>action_name/result.rhtml</tt>
    # * <tt>action_name/layout.rhtml</tt>
    #
    # Where <tt>action_name</tt> is the name of the action you gave to ClassMethods#web_service_scaffold.
    #
    # You can use the default views in <tt>RAILS_DIR/lib/action_web_service/templates/scaffolds</tt> as
    # a guide.
    module ClassMethods
      # Generates web service invocation scaffolding for the current controller. The given action name
      # can then be used as the entry point for invoking API methods from a web browser.
      def web_service_scaffold(action_name)
        add_template_helper(Helpers)
        module_eval <<-END, __FILE__, __LINE__
          def #{action_name}
            if @request.method == :get
              setup_#{action_name}_assigns
              render_#{action_name}_scaffold 'methods'
            end
          end

          def #{action_name}_method_params
            if @request.method == :get
              setup_#{action_name}_assigns
              render_#{action_name}_scaffold 'parameters'
            end
          end

          def #{action_name}_submit
            if @request.method == :post
              setup_#{action_name}_assigns
              protocol_name = @params['protocol'] ? @params['protocol'].to_sym : :soap
              case protocol_name
              when :soap
                protocol = Protocol::Soap::SoapProtocol.new
              when :xmlrpc
                protocol = Protocol::XmlRpc::XmlRpcProtocol.new
              end
              cgi = @request.cgi
              bm = Benchmark.measure do
                @method_request_xml = @scaffold_method.encode_rpc_call(protocol.marshaler, protocol.encoder, @params['method_params'].dup)
                @request = protocol.create_action_pack_request(@scaffold_service.name, @scaffold_method.public_name, @method_request_xml)
                dispatch_web_service_request
                @method_response_xml = @response.body
                @method_return_value = protocol.marshaler.unmarshal(protocol.encoder.decode_rpc_response(@method_response_xml)[1]).value
              end
              @method_elapsed = bm.real
              add_instance_variables_to_assigns
              @response = ::ActionController::CgiResponse.new(cgi)
              @performed_render = false
              render_#{action_name}_scaffold 'result'
            end
          end

          private
            def setup_#{action_name}_assigns
              @scaffold_class = self.class
              @scaffold_action_name = "#{action_name}"
              @scaffold_container = WebServiceModel::Container.new(self)
              if @params['service'] && @params['method']
                @scaffold_service = @scaffold_container.services.find{ |x| x.name == @params['service'] }
                @scaffold_method = @scaffold_service.api_methods[@params['method']]
              end
              add_instance_variables_to_assigns
            end

            def render_#{action_name}_scaffold(action)
              customized_template = "\#{self.class.controller_path}/#{action_name}/\#{action}"
              default_template = scaffold_path(action)
              @content_for_layout = template_exists?(customized_template) ? @template.render_file(customized_template) : @template.render_file(default_template, false)
              self.active_layout ? render_file(self.active_layout, "200 OK", true) : render_file(scaffold_path("layout"))
            end

            def scaffold_path(template_name)
              File.dirname(__FILE__) + "/templates/scaffolds/" + template_name + ".rhtml"
            end
        END
      end
    end

    module Helpers # :nodoc:
      def method_parameter_input_fields(method, param_spec, i)
        klass = method.param_class(param_spec)
        unless WS::BaseTypes.base_type?(klass)
          name = method.param_name(param_spec, i)
          raise "Parameter #{name}: Structured/array types not supported in scaffolding input fields yet"
        end
        type_name = method.param_type(param_spec)
        field_name = "method_params[]"
        case type_name
        when :int
          text_field_tag field_name
        when :string
          text_field_tag field_name
        when :bool
          radio_button_tag field_name, "True"
          radio_button_tag field_name, "False"
        when :float
          text_field_tag field_name
        when :time
          select_datetime Time.now, 'name' => field_name
        when :date
          select_date Date.today, 'name' => field_name
        end
      end

      def service_method_list(service)
        action = @scaffold_action_name + '_method_params'
        methods = service.api_methods_full.map do |desc, name|
          content_tag("li", link_to(desc, :action => action, :service => service.name, :method => name))
        end
        content_tag("ul", methods.join("\n"))
      end
    end

    module WebServiceModel # :nodoc:
      class Container # :nodoc:
        attr :services

        def initialize(real_container)
          @real_container = real_container
          @services = []
          if @real_container.class.web_service_dispatching_mode == :direct
            @services << Service.new(@real_container.controller_name, @real_container)
          else
            @real_container.class.web_services.each do |name|
              @services << Service.new(name, @real_container.instance_eval{ web_service_object(name) })
            end
          end
        end
      end

      class Service # :nodoc:
        attr :name
        attr :object
        attr :api
        attr :api_methods
        attr :api_methods_full

        def initialize(name, real_service)
          @name = name.to_s
          @object = real_service
          @api = @object.class.web_service_api
          @api_methods = {}
          @api_methods_full = []
          @api.api_methods.each do |name, method|
            @api_methods[method.public_name.to_s] = method
            @api_methods_full << [method.to_s, method.public_name.to_s]
          end
        end

        def to_s
          self.name.camelize
        end
      end
    end
  end
end
