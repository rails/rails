# frozen_string_literal: true

require "abstract_unit"

module RenderFile
  class BasicController < ActionController::Base
    self.view_paths = __dir__

    def index
      render file: File.expand_path("../../fixtures/test/hello_world.erb", __dir__)
    end

    def pathname
      render file: Pathname.new(__dir__).join(*%w[.. .. fixtures test dot.directory render_file_with_ivar.erb])
    end
  end

  class TestBasic < Rack::TestCase
    testing RenderFile::BasicController

    test "rendering simple file" do
      get :index
      assert_response "Hello world!"
    end

    test "rendering a Pathname" do
      get :pathname
      assert_response "The secret is <%= @secret %>\n"
    end
  end
end
