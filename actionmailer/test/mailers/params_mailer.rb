# frozen_string_literal: true

class ParamsMailer < ActionMailer::Base
  before_action { @inviter, @invitee = params[:inviter], params[:invitee] }

  default to: Proc.new { @invitee }, from: -> { @inviter }

  def invitation
    mail(subject: 'Welcome to the project!') do |format|
      format.text { render plain: "So says #{@inviter}" }
    end
  end
end
