class RescueJob < ActiveJob::Base
  class OtherError < StandardError; end

  rescue_from(ArgumentError) do
    Thread.current[:ajbuffer] << "rescued from ArgumentError"
    arguments[0] = "DIFFERENT!"
    retry_now
  end

  def perform(person = "david")
    case person
    when "david"
      raise ArgumentError, "Hair too good"
    when "other"
      raise OtherError
    else
      Thread.current[:ajbuffer] << "performed beautifully"
    end
  end
end
