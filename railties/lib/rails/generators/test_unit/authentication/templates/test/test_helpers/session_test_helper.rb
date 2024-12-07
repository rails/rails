module SessionTestHelper
  def sign_in(user)
    user = users(user) unless user.is_a? User
    post session_path, params: { email_address: user.email_address, password: "password" }
  end

  def sign_out
    delete session_path
  end

  def parsed_cookies
    ActionDispatch::Cookies::CookieJar.build(request, cookies.to_hash)
  end
end
