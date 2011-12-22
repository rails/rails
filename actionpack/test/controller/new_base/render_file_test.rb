require 'abstract_unit'

module RenderFile
  class BasicController < ActionController::Base
    self.view_paths = File.dirname(__FILE__)

    def index
      render :file => File.join(File.dirname(__FILE__), *%w[.. .. fixtures test hello_world])
    end

    def with_instance_variables
      @secret = 'in the sauce'
      render :file => File.join(File.dirname(__FILE__), '../../fixtures/test/render_file_with_ivar')
    end

    def without_file_key
      render File.join(File.dirname(__FILE__), *%w[.. .. fixtures test hello_world])
    end

    def without_file_key_with_instance_variable
      @secret = 'in the sauce'
      render File.join(File.dirname(__FILE__), '../../fixtures/test/render_file_with_ivar')
    end

    def relative_path
      @secret = 'in the sauce'
      render :file => '../../fixtures/test/render_file_with_ivar'
    end

    def relative_path_with_dot
      @secret = 'in the sauce'
      render :file => '../../fixtures/test/dot.directory/render_file_with_ivar'
    end

    def pathname
      @secret = 'in the sauce'
      render :file => Pathname.new(File.dirname(__FILE__)).join(*%w[.. .. fixtures test dot.directory render_file_with_ivar])
    end

    def with_locals
      path = File.join(File.dirname(__FILE__), '../../fixtures/test/render_file_with_locals')
      render :file => path, :locals => {:secret => 'in the sauce'}
    end

    def without_file_key_with_locals
      path = FIXTURES.join('test/render_file_with_locals').to_s
      render path, :locals => {:secret => 'in the sauce'}
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

    test "rendering path without specifying the :file key" do
      get :without_file_key
      assert_response "Hello world!"
    end

    test "rendering path without specifying the :file key with ivar" do
      get :without_file_key_with_instance_variable
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

    test "rendering path without specifying the :file key with locals" do
      get :without_file_key_with_locals
      assert_response "The secret is in the sauce\n"
    end
  end
end
