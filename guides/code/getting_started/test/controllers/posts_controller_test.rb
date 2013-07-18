require 'test_helper'

class PostsControllerTest < ActionController::TestCase
   test "should get index" do
    get :index
    assert_response :success
  end

  test "should create a post" do 
  	@request.env['HTTP_AUTHORIZATION'] = authenticate_with
  	post(:create, post: { title: "Love Hina", text: "This is a dummy text" })
  	assert_not_nil Post.find_by(title: "Love Hina")
  end

  test "should render to new if error in post create" do 
  	@request.env['HTTP_AUTHORIZATION'] = authenticate_with
  	post(:create, post: { title: "L", text: "This is a dummy text" })
  	assert_template 'new'
  end

  private
  	def authenticate_with
  	  ActionController::HttpAuthentication::Basic.encode_credentials('dhh', 'secret')
  	end
end
