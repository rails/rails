require 'abstract_unit'

module ActionArgsTest
  class ActionArgsController < ActionController::Metal
    include ActionController::ActionArgs
    include ActionController::Rendering

    permits :title, :body

    def get(name, address)
      render text: "Name: #{name}, Address: #{address}"
    end

    def show(name, action_arg)
      render text: "Name: #{name}, Title: #{action_arg[:title]}, Body: #{action_arg[:body]}#{action_arg[:admin]}"
    end

    #if RUBY_VERSION >= "2.0"
      #class_eval <<-RUBY, __FILE__, __LINE__ + 1
        #def keywords(action_arg, address: 'Unknown')
          #render text: "Address: \#{address}, Title: \#{action_arg[:title]}, Body: \#{action_arg[:body]}\#{action_arg[:admin]}"
        #end
      #RUBY
    #end
  end

  class Simple < Rack::TestCase
    def app
      ActionArgsController.action(:get)
    end

    def test_simple_args
      get "/action_args/get", { name: 'Erik', address: 'San Francisco' }
      assert_body "Name: Erik, Address: San Francisco"
    end

    def test_inadequate_args
      assert_raises(ActionController::ParameterMissing) do
        get "/action_args/get"
      end
    end
  end

  class Nested < Rack::TestCase
    def app
      ActionArgsController.action(:show)
    end

    def test_nested
      get "/action_args/show", { name: 'David', action_arg: { title: "First Post", body: "This is the first post" } }
      assert_body "Name: David, Title: First Post, Body: This is the first post"
    end

    def test_invalid_param
      get "/action_args/show", { name: 'David', action_arg: { title: "First Post", body: "This is the first post", admin: 'haha' } }
      assert_body "Name: David, Title: First Post, Body: This is the first post"
    end
  end

  #if RUBY_VERSION >= "2"
    #class KeywordArgs < Rack::TestCase
      #def app
        #ActionArgsController.action(:keywords)
      #end

      #def test_nested
        #get "/action_args/show", { action_arg: { title: "First Post", body: "This is the first post" } }
        #assert_body "Address: Unknown, Title: First Post, Body: This is the first post"
      #end

      #def test_invalid_param
        #get "/action_args/show", { address: 'San Francisco', action_arg: { title: "First Post", body: "This is the first post", admin: 'haha' } }
        #assert_body "Address: San Francisco, Title: First Post, Body: This is the first post"
      #end
    #end
  #end
end
