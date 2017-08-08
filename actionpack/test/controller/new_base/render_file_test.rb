# frozen_string_literal: true

require "abstract_unit"

module RenderFile
  class BasicController < ActionController::Base
    self.view_paths = __dir__

    def index
      render file: File.expand_path("../../fixtures/test/hello_world", __dir__)
    end

    def with_instance_variables
      @secret = "in the sauce"
      render file: File.expand_path("../../fixtures/test/render_file_with_ivar", __dir__)
    end

    def relative_path
      @secret = "in the sauce"
      render file: "../../fixtures/test/render_file_with_ivar"
    end

    def relative_path_with_dot
      @secret = "in the sauce"
      render file: "../../fixtures/test/dot.directory/render_file_with_ivar"
    end

    def pathname
      @secret = "in the sauce"
      render file: Pathname.new(__dir__).join(*%w[.. .. fixtures test dot.directory render_file_with_ivar])
    end

    def with_locals
      path = File.expand_path("../../fixtures/test/render_file_with_locals", __dir__)
      render file: path, locals: { secret: "in the sauce" }
    end
  end

  class TestBasic < Rack::TestCase
    testing RenderFile::BasicController

    test "rendering simple template" do
      get :index
      assert_response "Hello world!"
    end

    test "rendering template with ivar" do
      get :with_instance_variables
      assert_response "The secret is in the sauce\n"
    end

    test "rendering a relative path" do
      get :relative_path
      assert_response "The secret is in the sauce\n"
    end

    test "rendering a relative path with dot" do
      get :relative_path_with_dot
      assert_response "The secret is in the sauce\n"
    end

    test "rendering a Pathname" do
      get :pathname
      assert_response "The secret is in the sauce\n"
    end

    test "rendering file with locals" do
      get :with_locals
      assert_response "The secret is in the sauce\n"
    end
  end
end
