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
      render file: "../actionpack/test/fixtures/test/render_file_with_ivar"
    end

    def relative_path_with_dot
      @secret = "in the sauce"
      render file: "../actionpack/test/fixtures/test/dot.directory/render_file_with_ivar"
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
      assert_deprecated do
        get :index
      end
      assert_response "Hello world!"
    end

    test "rendering template with ivar" do
      assert_deprecated do
        get :with_instance_variables
      end
      assert_response "The secret is in the sauce\n"
    end

    test "rendering a relative path" do
      assert_deprecated do
        get :relative_path
      end
      assert_response "The secret is in the sauce\n"
    end

    test "rendering a relative path with dot" do
      assert_deprecated do
        get :relative_path_with_dot
      end
      assert_response "The secret is in the sauce\n"
    end

    test "rendering a Pathname" do
      assert_deprecated do
        get :pathname
      end
      assert_response "The secret is in the sauce\n"
    end

    test "rendering file with locals" do
      assert_deprecated do
        get :with_locals
      end
      assert_response "The secret is in the sauce\n"
    end
  end
end
