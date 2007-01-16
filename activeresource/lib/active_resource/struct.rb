module ActiveResource
  # Class that allows a connection to a remote resource.
  #  Person = ActiveResource::Struct.new do |p|
  #    p.uri "http://www.mypeople.com/people"
  #    p.credentials :username => "mycreds", :password => "wordofpassage"
  #  end
  #
  #  person = Person.find(1)
  #  person.name = "David"
  #  person.save!
  class Struct
    def self.create
      Class.new(Base)
    end
  end
end