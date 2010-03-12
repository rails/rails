require "abstract_unit"
require "fixtures/person"
require "rails/log_subscriber/test_helper"
require "active_resource/railties/log_subscriber"
require "active_support/core_ext/hash/conversions"

# TODO: This test should be part of Railties
class LogSubscriberTest < ActiveSupport::TestCase
  include Rails::LogSubscriber::TestHelper

  def setup
    super

    @matz = { :id => 1, :name => 'Matz' }.to_xml(:root => 'person')
    ActiveResource::HttpMock.respond_to do |mock|
      mock.get "/people/1.xml", {}, @matz
    end

    Rails::LogSubscriber.add(:active_resource, ActiveResource::Railties::LogSubscriber.new)
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
