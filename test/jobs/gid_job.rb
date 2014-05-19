class GidJob < ActiveJob::Base
  def self.perform(person)
    $BUFFER << "Person with ID: #{person.id}"
  end
end
  