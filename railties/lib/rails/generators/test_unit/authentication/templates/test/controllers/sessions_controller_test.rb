require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup { @user = User.take }

  test "new" do
    get new_session_url
    assert_response :success
  end

  test "create with valid credentials" do
    post session_url, params: { email_address: @user.email_address, password: "password" }

    assert_redirected_to root_url
    assert cookies[:session_id]
  end

  test "create with invalid credentials" do
    post session_url, params: { email_address: @user.email_address, password: "wrong" }

    assert_redirected_to new_session_url
    assert_nil cookies[:session_id]
  end

  test "destroy" do
    sign_in_as(User.take)

    delete session_url

    assert_redirected_to new_session_url
    assert_empty cookies[:session_id]
  end
end
