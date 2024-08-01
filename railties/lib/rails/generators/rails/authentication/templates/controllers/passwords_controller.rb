class PasswordsController < ApplicationController
  allow_unauthenticated_access

  rescue_from "ActiveSupport::MessageVerifier::InvalidSignature" do
    redirect_to new_password_url, alert: "Password reset link is invalid or has expired."
  end

  def new
  end

  def create
    if user = User.find_by(email_address: params[:email_address])
      PasswordsMailer.reset(user).deliver_later
    end

    redirect_to new_session_url, notice: "Password reset instructions sent (if user with that email address exists)."
  end

  def edit
    @user = find_user_by_token
  end

  def update
    if find_user_by_token.update(params.permit(:password, :password_confirmation))
      redirect_to new_session_url, notice: "Password has been reset."
    else
      redirect_to edit_password_url(params[:token]), alert: "Passwords did not match."
    end
  end

  private
    def find_user_by_token
      User.find_signed!(params[:token], purpose: "password")
    end
end

