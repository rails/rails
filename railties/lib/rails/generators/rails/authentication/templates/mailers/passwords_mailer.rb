class PasswordsMailer < ApplicationMailer
  def reset(user)
    @token = user.signed_id(purpose: "password", expires_in: 15.minutes)
    mail subject: "Reset your password", to: user.email_address, from: "passwords@example.com"
  end
end

