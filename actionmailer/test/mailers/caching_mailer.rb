class CachingMailer < ActionMailer::Base
  self.mailer_name = "caching_mailer"

  def fragment_cache
    mail(subject: "welcome", template_name: "fragment_cache")
  end
end
