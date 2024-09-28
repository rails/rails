class PasswordsController < ApplicationController
  allow_unauthenticated_access
  before_action :redirect_on_token, only: :edit
  before_action :set_user_by_token, only: %i[ edit update ]

  def new
  end

  def create
    if user = User.find_by(email_address: params[:email_address])
      PasswordsMailer.reset(user).deliver_later
    end

    redirect_to new_session_url, notice: "Password reset instructions sent (if user with that email address exists)."
  end

  def edit
  end

  def update
    if @user.update(params.permit(:password, :password_confirmation))
      redirect_to new_session_url, notice: "Password has been reset."
    else
      redirect_to edit_password_url, alert: "Passwords did not match."
    end
  end

  private
    def redirect_on_token
      if params[:token]
        session[:token] = params[:token]
        redirect_to edit_password_url
      end
    end

    def set_user_by_token
      @user = User.find_by_password_reset_token!(session[:token])
    rescue ActiveSupport::MessageVerifier::InvalidSignature
      session.delete(:token) if session[:token]
      redirect_to new_password_url, alert: "Password reset link is invalid or has expired."
    end
end
