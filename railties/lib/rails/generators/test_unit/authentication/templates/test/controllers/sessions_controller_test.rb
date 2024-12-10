require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "new" do
    get new_session_url
    assert_response :success
  end

  test "create with valid credentials" do
    post session_url, params: { email_address: "one@example.com", password: "password" }

    assert_redirected_to root_url
    assert parsed_cookies.signed[:session_id]
  end

  test "create with invalid credentials" do
    post session_url, params: { email_address: "one@example.com", password: "wrong" }

    assert_redirected_to new_session_url
    assert_nil parsed_cookies.signed[:session_id]
  end

  test "destroy" do
    sign_in :one

    delete session_url

    assert_redirected_to new_session_url
    assert_empty cookies[:session_id]
  end
end
