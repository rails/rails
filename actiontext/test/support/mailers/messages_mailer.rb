class MessagesMailer < ApplicationMailer
  def notification
    @message = params[:message]
    mail to: params[:recipient], subject: "NEW MESSAGE: #{@message.subject}"
  end
end
