require "action_controller/testing/process"

module ActionController
  module TestProcess
    
    # Executes a request simulating GET HTTP method and set/volley the response
    def get(action, parameters = nil, session = nil, flash = nil)
      process(action, parameters, session, flash, "GET")
    end

    # Executes a request simulating POST HTTP method and set/volley the response
    def post(action, parameters = nil, session = nil, flash = nil)
      process(action, parameters, session, flash, "POST")
    end

    # Executes a request simulating PUT HTTP method and set/volley the response
    def put(action, parameters = nil, session = nil, flash = nil)
      process(action, parameters, session, flash, "PUT")
    end

    # Executes a request simulating DELETE HTTP method and set/volley the response
    def delete(action, parameters = nil, session = nil, flash = nil)
      process(action, parameters, session, flash, "DELETE")
    end

    # Executes a request simulating HEAD HTTP method and set/volley the response
    def head(action, parameters = nil, session = nil, flash = nil)
      process(action, parameters, session, flash, "HEAD")
    end

    def process(action, parameters = nil, session = nil, flash = nil, http_method = 'GET')
      # Sanity check for required instance variables so we can give an
      # understandable error message.
      %w(@controller @request @response).each do |iv_name|
        if !(instance_variable_names.include?(iv_name) || instance_variable_names.include?(iv_name.to_sym)) || instance_variable_get(iv_name).nil?
          raise "#{iv_name} is nil: make sure you set it in your test's setup method."
        end
      end

      @request.recycle!
      @response.recycle!
      @controller.response_body = nil
      @controller.formats = nil
      @controller.params = nil

      @html_document = nil
      @request.env['REQUEST_METHOD'] = http_method

      parameters ||= {}
      @request.assign_parameters(@controller.class.controller_path, action.to_s, parameters)

      @request.session = ActionController::TestSession.new(session) unless session.nil?
      @request.session["flash"] = ActionController::Flash::FlashHash.new.update(flash) if flash

      @controller.request = @request
      @controller.params.merge!(parameters)
      build_request_uri(action, parameters)
      # Base.class_eval { include ProcessWithTest } unless Base < ProcessWithTest
      @controller.process_with_new_base_test(@request, @response)
      @response
    end
    
    def build_request_uri(action, parameters)
      unless @request.env['REQUEST_URI']
        options = @controller.__send__(:rewrite_options, parameters)
        options.update(:only_path => true, :action => action)

        url = ActionController::UrlRewriter.new(@request, parameters)
        @request.request_uri = url.rewrite(options)
      end
    end      
      
  end
end