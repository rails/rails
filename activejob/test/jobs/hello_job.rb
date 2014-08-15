class HelloJob < ActiveJob::Base
  def perform(greeter = "David")
    Thread.current[:ajbuffer] << "#{greeter} says hello"
  end
end
