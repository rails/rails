class RescueJob < ActiveJob::Base
  rescue_from(StandardError) do
    $BUFFER << "rescued from StandardError"
    arguments[0] = "DIFFERENT!"
    retry_now
  end

  def perform(person = "david")
    if person == "david"
      raise "Hair too good"
    else
      $BUFFER << "performed beautifully"
    end
  end
end
