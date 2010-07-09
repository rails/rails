require "abstract_unit"
require "fixtures/person"
require "active_support/log_subscriber/test_helper"
require "active_resource/log_subscriber"
require "active_support/core_ext/hash/conversions"

class LogSubscriberTest < ActiveSupport::TestCase
  include ActiveSupport::LogSubscriber::TestHelper

  def setup
    super

    @matz = { :id => 1, :name => 'Matz' }.to_xml(:root => 'person')
    ActiveResource::HttpMock.respond_to do |mock|
      mock.get "/people/1.xml", {}, @matz
    end

    ActiveResource::LogSubscriber.attach_to :active_resource
  end

  def set_logger(logger)
    ActiveResource::Base.logger = logger
  end

  def test_request_notification
    matz = Person.find(1)
    wait
    assert_equal 2, @logger.logged(:info).size
    assert_equal "GET http://37s.sunrise.i:3000/people/1.xml", @logger.logged(:info)[0]
    assert_match(/\-\-\> 200 200 106/, @logger.logged(:info)[1])
  end
end
