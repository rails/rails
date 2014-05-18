class HelloJob < ActiveJob::Base
  @queue = :greetings

  def self.perform(greeter = "David")
    $BUFFER << "#{greeter} says hello"
  end
end
