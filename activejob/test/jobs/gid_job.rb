class GidJob < ActiveJob::Base
  def perform(person)
    JobBuffer.add("Person with ID: #{person.id}")
  end
end

