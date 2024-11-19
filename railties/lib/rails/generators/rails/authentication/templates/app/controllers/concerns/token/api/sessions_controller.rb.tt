class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_url, alert: "Try again later." }

  def new
  end

  def create
    if user = User.authenticate_by(params.permit(:email_address, :password))
      token = start_new_session_for user
      render json: { token: token }, status: :created
    else
      render json: { error: "Unauthorized" }, status: :unauthorized
    end
  end

  def destroy
    terminate_session
    render json: { message: "Session terminated" }, status: :ok
  end
end
