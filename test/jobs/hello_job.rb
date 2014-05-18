class HelloJob < ActiveJob::Base
  def self.perform(greeter = "David")
    $BUFFER << "#{greeter} says hello"
  end
end
