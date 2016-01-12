require_relative '../../../actionmailer/lib/action_mailer'
require_relative '../support/job_buffer'

class MailerJob < ActionMailer::Base
  def welcome(email)
    JobBuffer.add("Welcome, #{email}!")
  end

  def welcome_person(user)
    JobBuffer.add("Welcome, #{user.id}!")
  end

  def welcome_both(user, email)
    JobBuffer.add("Welcome, #{email}! Your id is #{user.id}")
  end
end
