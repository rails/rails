require "abstract_unit"
require "fixtures/person"
require "rails/subscriber/test_helper"
require "active_resource/railties/subscriber"
require "active_support/core_ext/hash/conversions"

class SubscriberTest < ActiveSupport::TestCase
  include Rails::Subscriber::TestHelper
  Rails::Subscriber.add(:active_resource, ActiveResource::Railties::Subscriber.new)

  def setup
    @matz = { :id => 1, :name => 'Matz' }.to_xml(:root => 'person')
    ActiveResource::HttpMock.respond_to do |mock|
      mock.get "/people/1.xml", {}, @matz
    end

    super
  end

  def set_logger(logger)
    ActiveResource::Base.logger = logger
  end

  def test_request_notification
    matz = Person.find(1)
    wait
    assert_equal 2, @logger.logged(:info).size
    assert_equal "GET http://37s.sunrise.i:3000/people/1.xml", @logger.logged(:info)[0]
    assert_match /\-\-\> 200 200 106/, @logger.logged(:info)[1]
  end
end