class AssetMailer < ActionMailer::Base
  self.mailer_name = "asset_mailer"

  def welcome
    mail
  end
end
