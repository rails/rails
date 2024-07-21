class RegistrationsController < ApplicationController
  allow_unauthenticated_access
  before_action :resume_session, only: :new
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_url, alert: "Try again later." }

  def new
    redirect_to root_url if authenticated?
  end

  def create
    user = User.new(params.permit(:email_address, :password))
    if user.save
      start_new_session_for user
      redirect_to after_authentication_url
    else
      redirect_to new_registration_url(email_address: params[:email_address]), alert: user.errors.full_messages.to_sentence
    end
  end
end
