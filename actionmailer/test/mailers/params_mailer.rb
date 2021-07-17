# frozen_string_literal: true

class ParamsMailer < ActionMailer::Base
  before_action { @inviter, @invitee, @locale = params[:inviter], params[:invitee], params[:locale] }

  default to: Proc.new { @invitee }, from: -> { @inviter }, locale: -> { @locale }

  def invitation
    mail do |format|
      format.text { render plain: "So says #{@inviter}" }
    end
  end
end
