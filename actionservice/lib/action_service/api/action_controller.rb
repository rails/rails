module ActionService # :nodoc:
  module API # :nodoc:
    module ActionController # :nodoc:
      def self.append_features(base) # :nodoc:
        base.class_eval do 
          class << self
            alias_method :inherited_without_api, :inherited
            alias_method :service_api_without_require, :service_api
          end
        end
        base.extend(ClassMethods)
      end

      module ClassMethods
        # Creates a _protected_ factory method with the given
        # +name+. This method will create a +protocol+ client connected
        # to the given endpoint URL.
        #
        # ==== Example
        #
        #   class MyController < ActionController::Base
        #     client_api :blogger, :xmlrpc, "http://blogger.com/myblog/api/RPC2", :handler_name => 'blogger'
        #   end
        #
        # In this example, a protected method named <tt>blogger</tt> will
        # now exist on the controller, and calling it will return the
        # XML-RPC client object for working with that remote service.
        #
        # The same rules as ActionService::API::Base#service_api are
        # used to retrieve the API definition with the given +name+.
        #
        # +options+ is the set of protocol client specific options,
        # see the protocol client class for details.
        #
        # If your API definition does not exist on the load path
        # with the correct rules for it to be found, you can
        # pass through the API definition class in +options+, using
        # a key of <tt>:api</tt>
        def client_api(name, protocol, endpoint_uri, options={})
          unless method_defined?(name)
            api_klass = options.delete(:api) || require_api(name)
            class_eval do
              define_method(name) do
                probe_protocol_client(api_klass, protocol, endpoint_uri, options)
              end
              protected name
            end
          end
        end

        def service_api(definition=nil) # :nodoc:
          return service_api_without_require if definition.nil?
          case definition
          when String, Symbol
            klass = require_api(definition)
          else
            klass = definition
          end
          service_api_without_require(klass)
        end

        def require_api(name) # :nodoc:
          case name
          when String, Symbol
            file_name = name.to_s.underscore + "_api"
            class_name = file_name.camelize
            class_names = [class_name, class_name.sub(/Api$/, 'API')]
            begin
              require_dependency(file_name)
            rescue LoadError => load_error
              requiree = / -- (.*?)(\.rb)?$/.match(load_error).to_a[1]
              raise LoadError, requiree == file_name ? "Missing API definition file in apis/#{file_name}.rb" : "Can't load file: #{requiree}"
            end
            klass = nil
            class_names.each do |name|
              klass = name.constantize rescue nil
              break unless klass.nil?
            end
            unless klass
              raise(NameError, "neither #{class_names[0]} or #{class_names[1]} found")
            end
            klass
          else
            raise(ArgumentError, "expected String or Symbol argument")
          end
        end

        private
          def inherited(child)
            inherited_without_api(child)
            child.service_api(child.controller_path)
          rescue Exception => e
          end
      end
    end
  end
end
