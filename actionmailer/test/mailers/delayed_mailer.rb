class DelayedMailer < ActionMailer::Base

  def test_message(*)
    mail(from: 'test-sender@test.com', to: 'test-receiver@test.com', subject: 'Test Subject', body: 'Test Body')
  end
end
