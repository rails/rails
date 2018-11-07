class Mail::Message
  def recipients
    Array(to) + Array(cc) + Array(bcc)
  end
end
