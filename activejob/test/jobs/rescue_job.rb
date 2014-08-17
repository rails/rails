class RescueJob < ActiveJob::Base
  class OtherError < StandardError; end

  rescue_from(ArgumentError) do
    JobBuffer.add('rescued from ArgumentError')
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
      JobBuffer.add('performed beautifully')
    end
  end
end
