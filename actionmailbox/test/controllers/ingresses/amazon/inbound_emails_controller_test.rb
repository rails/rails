# frozen_string_literal: true

require "test_helper"

class ActionMailbox::Ingresses::Amazon::InboundEmailsControllerTest < ActionDispatch::IntegrationTest
  def fixture(name)
    file_fixture("../files/amazon/#{name}").read
  end

  def json_fixture(name)
    JSON.parse(fixture("#{name}.json"))
  end

  setup do
    ActionMailbox.ingress = :amazon
    ActionMailbox.amazon = ActiveSupport::OrderedOptions.new
    ActionMailbox.amazon.subscribed_topics = %w(
      arn:aws:sns:eu-west-1:111111111111:example-topic
      arn:aws:sns:eu-west-1:111111111111:recognized-topic
    )
    pem_url = "https://sns.eu-west-1.amazonaws.com/SimpleNotificationService-a86cb10b4e1f29c941702d737128f7b6.pem"
    stub_request(:get, pem_url).and_return(body: fixture("certificate.pem"))
    @inbound = json_fixture("inbound_email")
    @inbound_s3 = json_fixture("inbound_email_s3")
    @s3_email = fixture("s3_email.txt")
    @invalid_signature = json_fixture("invalid_signature")
    @valid_signature = json_fixture("valid_signature")
    @recognized_topic = json_fixture("recognized_topic_subscription_request")
    @unrecognized_topic = json_fixture("unrecognized_topic_subscription_request")
  end

  teardown do
    if Kernel.const_defined? :Aws
      Aws.config[:s3] = {}
    end
  end
  test "receiving an inbound email from Amazon" do
    assert_difference -> { ActionMailbox::InboundEmail.count }, +1 do
      post rails_amazon_inbound_emails_url, params: @inbound, as: :json
    end

    assert_response :no_content

    inbound_email = ActionMailbox::InboundEmail.last
    content = JSON.parse(@inbound["Message"])["content"]
    assert_equal inbound_email.raw_email.download, content
    id = "CA+X1WqWD+ZHUimo+gm+=TZt7haLJv9G7LjG4M-wu5ka=CwxpYQ@mail.gmail.com"
    assert_equal inbound_email.message_id, id
  end

  test "receiving an inbound email with an s3 action configured" do
    require "aws-sdk-s3"
    Aws.config[:s3] = {
      stub_responses: {
        head_object: { content_length: @s3_email.size, parts_count: 1 },
        get_object: { body: @s3_email }
      }
    }

    assert_difference -> { ActionMailbox::InboundEmail.count }, +1 do
      post rails_amazon_inbound_emails_url, params: @inbound_s3, as: :json
    end

    assert_response :no_content

    inbound_email = ActionMailbox::InboundEmail.last
    assert_equal inbound_email.raw_email.download, @s3_email
    id = "1344C740-07D3-476E-BEE7-6EB162294DF6@example.com"
    assert_equal inbound_email.message_id, id
  end

  test "accepting subscriptions to recognized topics" do
    params = {
      Action: "ConfirmSubscription",
      Token: "abcd1234" * 32,
      TopicArn: "arn:aws:sns:eu-west-1:111111111111:recognized-topic"
    }
    query = Rack::Utils.build_query(params)
    request = stub_request(:get, "https://sns.eu-west-1.amazonaws.com/?#{query}")
    post rails_amazon_inbound_emails_url, params: @recognized_topic, as: :json
    assert_requested request
  end

  test "rejecting subscriptions to unrecognized topics" do
    url = %r{https://sns.eu-west-1.amazonaws.com/\?Action=ConfirmSubscription}
    request = stub_request(:get, url)
    post rails_amazon_inbound_emails_url, params: @unrecognized_topic, as: :json
    assert_not_requested request
  end

  test "rejecting subscriptions with invalid signatures" do
    url = %r{https://sns.eu-west-1.amazonaws.com/\?Action=ConfirmSubscription}
    request = stub_request(:get, url)
    post rails_amazon_inbound_emails_url, params: @invalid_signature, as: :json
    assert_not_requested request
  end

  test "accepting subscriptions with valid signatures" do
    url = %r{https://sns.eu-west-1.amazonaws.com/\?Action=ConfirmSubscription}
    request = stub_request(:get, url)
    post rails_amazon_inbound_emails_url, params: @valid_signature, as: :json
    assert_requested request
  end
end
