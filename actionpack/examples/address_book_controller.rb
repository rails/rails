$:.unshift(File.dirname(__FILE__) + "/../lib")

require "action_controller"
require "action_controller/test_process"

Person = Struct.new("Person", :id, :name, :email_address, :phone_number)

class AddressBookService
  attr_reader :people

  def initialize()          @people = [] end
  def create_person(data)   people.unshift(Person.new(next_person_id, data["name"], data["email_address"], data["phone_number"])) end
  def find_person(topic_id) people.select { |person| person.id == person.to_i }.first end
  def next_person_id()      people.first.id + 1 end
end

class AddressBookController < ActionController::Base
  layout "address_book/layout"
  
  before_filter :initialize_session_storage
  
  # Could also have used a proc
  # before_filter proc { |c| c.instance_variable_set("@address_book", c.session["address_book"] ||= AddressBookService.new) } 

  def index
    @title  = "Address Book"
    @people = @address_book.people
  end
  
  def person
    @person = @address_book.find_person(params[:id])
  end
  
  def create_person
    @address_book.create_person(params[:person])
    redirect_to :action => "index"
  end
    
  private
    def initialize_session_storage
      @address_book = @session["address_book"] ||= AddressBookService.new
    end
end

ActionController::Base.view_paths = [ File.dirname(__FILE__) ]
# ActionController::Base.logger = Logger.new("debug.log") # Remove first comment to turn on logging in current dir

begin
  AddressBookController.process_cgi(CGI.new) if $0 == __FILE__
rescue => e
  CGI.new.out { "#{e.class}: #{e.message}" }
end
