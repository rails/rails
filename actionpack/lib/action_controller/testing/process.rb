require 'active_support/core_ext/object/conversions'
require "rack/test"

module ActionController #:nodoc:
  # Essentially generates a modified Tempfile object similar to the object
  # you'd get from the standard library CGI module in a multipart
  # request. This means you can use an ActionController::TestUploadedFile
  # object in the params of a test request in order to simulate
  # a file upload.
  #
  # Usage example, within a functional test:
  #   post :change_avatar, :avatar => ActionController::TestUploadedFile.new(ActionController::TestCase.fixture_path + '/files/spongebob.png', 'image/png')
  #
  # Pass a true third parameter to ensure the uploaded file is opened in binary mode (only required for Windows):
  #   post :change_avatar, :avatar => ActionController::TestUploadedFile.new(ActionController::TestCase.fixture_path + '/files/spongebob.png', 'image/png', :binary)
  TestUploadedFile = Rack::Test::UploadedFile

  module TestProcess
    def assigns(key = nil)
      assigns = {}
      @controller.instance_variable_names.each do |ivar|
        next if ActionController::Base.protected_instance_variables.include?(ivar)
        assigns[ivar[1..-1]] = @controller.instance_variable_get(ivar)
      end

      key.nil? ? assigns : assigns[key.to_s]
    end

    def session
      @request.session
    end

    def flash
      @request.flash
    end

    def cookies
      @request.cookies.merge(@response.cookies)
    end

    def redirect_to_url
      @response.redirect_url
    end

    def html_document
      xml = @response.content_type =~ /xml$/
      @html_document ||= HTML::Document.new(@response.body, false, xml)
    end

    def find_tag(conditions)
      html_document.find(conditions)
    end

    def find_all_tag(conditions)
      html_document.find_all(conditions)
    end

    def method_missing(selector, *args, &block)
      if @controller && ActionController::Routing::Routes.named_routes.helpers.include?(selector)
        @controller.send(selector, *args, &block)
      else
        super
      end
    end

    # Shortcut for <tt>ActionController::TestUploadedFile.new(ActionController::TestCase.fixture_path + path, type)</tt>:
    #
    #   post :change_avatar, :avatar => fixture_file_upload('/files/spongebob.png', 'image/png')
    #
    # To upload binary files on Windows, pass <tt>:binary</tt> as the last parameter.
    # This will not affect other platforms:
    #
    #   post :change_avatar, :avatar => fixture_file_upload('/files/spongebob.png', 'image/png', :binary)
    def fixture_file_upload(path, mime_type = nil, binary = false)
      fixture_path = ActionController::TestCase.send(:fixture_path) if ActionController::TestCase.respond_to?(:fixture_path)
      ActionController::TestUploadedFile.new("#{fixture_path}#{path}", mime_type, binary)
    end

    # A helper to make it easier to test different route configurations.
    # This method temporarily replaces ActionController::Routing::Routes
    # with a new RouteSet instance.
    #
    # The new instance is yielded to the passed block. Typically the block
    # will create some routes using <tt>map.draw { map.connect ... }</tt>:
    #
    #   with_routing do |set|
    #     set.draw do |map|
    #       map.connect ':controller/:action/:id'
    #         assert_equal(
    #           ['/content/10/show', {}],
    #           map.generate(:controller => 'content', :id => 10, :action => 'show')
    #       end
    #     end
    #   end
    #
    def with_routing
      real_routes = ActionController::Routing::Routes
      ActionController::Routing.module_eval { remove_const :Routes }

      temporary_routes = ActionController::Routing::RouteSet.new
      ActionController::Routing.module_eval { const_set :Routes, temporary_routes }

      yield temporary_routes
    ensure
      if ActionController::Routing.const_defined? :Routes
        ActionController::Routing.module_eval { remove_const :Routes }
      end
      ActionController::Routing.const_set(:Routes, real_routes) if real_routes
    end
  end
end
