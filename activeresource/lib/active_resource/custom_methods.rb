require 'active_support/core_ext/object/blank'

module ActiveResource
  # A module to support custom REST methods and sub-resources, allowing you to break out
  # of the "default" REST methods with your own custom resource requests.  For example,
  # say you use Rails to expose a REST service and configure your routes with:
  #
  #    map.resources :people, :new => { :register => :post },
  #                           :member => { :promote => :put, :deactivate => :delete }
  #                           :collection => { :active => :get }
  #
  #  This route set creates routes for the following HTTP requests:
  #
  #    POST    /people/new/register.json # PeopleController.register
  #    PUT     /people/1/promote.json    # PeopleController.promote with :id => 1
  #    DELETE  /people/1/deactivate.json # PeopleController.deactivate with :id => 1
  #    GET     /people/active.json       # PeopleController.active
  #
  # Using this module, Active Resource can use these custom REST methods just like the
  # standard methods.
  #
  #   class Person < ActiveResource::Base
  #     self.site = "http://37s.sunrise.i:3000"
  #   end
  #
  #   Person.new(:name => 'Ryan').post(:register)  # POST /people/new/register.json
  #   # => { :id => 1, :name => 'Ryan' }
  #
  #   Person.find(1).put(:promote, :position => 'Manager') # PUT /people/1/promote.json
  #   Person.find(1).delete(:deactivate) # DELETE /people/1/deactivate.json
  #
  #   Person.get(:active)  # GET /people/active.json
  #   # => [{:id => 1, :name => 'Ryan'}, {:id => 2, :name => 'Joe'}]
  #
  module CustomMethods
    extend ActiveSupport::Concern

    included do
      class << self
        alias :orig_delete :delete

        # Invokes a GET to a given custom REST method. For example:
        #
        #   Person.get(:active)  # GET /people/active.json
        #   # => [{:id => 1, :name => 'Ryan'}, {:id => 2, :name => 'Joe'}]
        #
        #   Person.get(:active, :awesome => true)  # GET /people/active.json?awesome=true
        #   # => [{:id => 1, :name => 'Ryan'}]
        #
        # Note: the objects returned from this method are not automatically converted
        # into ActiveResource::Base instances - they are ordinary Hashes. If you are expecting
        # ActiveResource::Base instances, use the <tt>find</tt> class method with the
        # <tt>:from</tt> option. For example:
        #
        #   Person.find(:all, :from => :active)
        def get(custom_method_name, options = {})
          hashified = format.decode(connection.get(custom_method_collection_url(custom_method_name, options), headers).body)
          derooted  = Formats.remove_root(hashified)
          derooted.is_a?(Array) ? derooted.map { |e| Formats.remove_root(e) } : derooted
        end

        def post(custom_method_name, options = {}, body = '')
          connection.post(custom_method_collection_url(custom_method_name, options), body, headers)
        end

        def put(custom_method_name, options = {}, body = '')
          connection.put(custom_method_collection_url(custom_method_name, options), body, headers)
        end

        def delete(custom_method_name, options = {})
          # Need to jump through some hoops to retain the original class 'delete' method
          if custom_method_name.is_a?(Symbol)
            connection.delete(custom_method_collection_url(custom_method_name, options), headers)
          else
            orig_delete(custom_method_name, options)
          end
        end
      end
    end

    module ClassMethods
      def custom_method_collection_url(method_name, options = {})
        prefix_options, query_options = split_options(options)
        "#{prefix(prefix_options)}#{collection_name}/#{method_name}.#{format.extension}#{query_string(query_options)}"
      end
    end

    def get(method_name, options = {})
      self.class.format.decode(connection.get(custom_method_element_url(method_name, options), self.class.headers).body)
    end

    def post(method_name, options = {}, body = nil)
      request_body = body.blank? ? encode : body
      if new?
        connection.post(custom_method_new_element_url(method_name, options), request_body, self.class.headers)
      else
        connection.post(custom_method_element_url(method_name, options), request_body, self.class.headers)
      end
    end

    def put(method_name, options = {}, body = '')
      connection.put(custom_method_element_url(method_name, options), body, self.class.headers)
    end

    def delete(method_name, options = {})
      connection.delete(custom_method_element_url(method_name, options), self.class.headers)
    end


    private
      def custom_method_element_url(method_name, options = {})
        "#{self.class.prefix(prefix_options)}#{self.class.collection_name}/#{id}/#{method_name}.#{self.class.format.extension}#{self.class.__send__(:query_string, options)}"
      end

      def custom_method_new_element_url(method_name, options = {})
        "#{self.class.prefix(prefix_options)}#{self.class.collection_name}/new/#{method_name}.#{self.class.format.extension}#{self.class.__send__(:query_string, options)}"
      end
  end
end
