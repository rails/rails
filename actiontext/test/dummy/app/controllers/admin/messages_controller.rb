class Admin::MessagesController < ActionController::Base
  def show
    @message = Message.find(params[:id])
  end
end
