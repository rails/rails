require 'action_controller/abstract'
require 'active_support/core_ext/module/delegation'

module ActionController
  class Http < AbstractController::Base
    abstract!

    # :api: public
    attr_internal :params, :env

    # :api: public
    def self.controller_name
      @controller_name ||= controller_path.split("/").last
    end

    # :api: public
    def controller_name
      self.class.controller_name
    end

    # :api: public
    def self.controller_path
      @controller_path ||= self.name.sub(/Controller$/, '').underscore
    end

    # :api: public
    def controller_path
      self.class.controller_path
    end

    # :api: private
    def self.action_names
      action_methods
    end

    # :api: private
    def action_names
      action_methods
    end

    # :api: plugin
    def self.call(env)
      controller = new
      controller.call(env).to_rack
    end

    # The details below can be overridden to support a specific
    # Request and Response object. The default ActionController::Base
    # implementation includes RackConvenience, which makes a request
    # and response object available. You might wish to control the
    # environment and response manually for performance reasons.

    attr_internal :status, :headers, :content_type

    def initialize(*)
      @_headers = {}
      super
    end

    # Basic implements for content_type=, location=, and headers are
    # provided to reduce the dependency on the RackConvenience module
    # in Renderer and Redirector.

    def content_type=(type)
      headers["Content-Type"] = type.to_s
    end

    def location=(url)
      headers["Location"] = url
    end

    # :api: private
    def call(name, env)
      @_env = env
      process(name)
      to_rack
    end

    # :api: private
    def to_rack
      [status, headers, response_body]
    end

    def self.action(name)
      @actions ||= {}
      @actions[name.to_s] ||= proc do |env|
        new.call(name, env)
      end
    end
  end
end
