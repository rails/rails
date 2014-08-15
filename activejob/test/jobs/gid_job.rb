class GidJob < ActiveJob::Base
  def perform(person)
    Thread.current[:ajbuffer] << "Person with ID: #{person.id}"
  end
end

