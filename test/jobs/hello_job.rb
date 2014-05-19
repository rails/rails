class HelloJob < ActiveJob::Base
  def perform(greeter = "David")
    $BUFFER << "#{greeter} says hello"
  end
end
