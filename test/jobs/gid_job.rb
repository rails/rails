class GidJob < ActiveJob::Base
  def perform(person)
    $BUFFER << "Person with ID: #{person.id}"
  end
end
  