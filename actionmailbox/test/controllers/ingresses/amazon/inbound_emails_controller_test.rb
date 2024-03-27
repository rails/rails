# frozen_string_literal: true

require "test_helper"

class ActionMailbox::Ingresses::AmazonSes::InboundEmailsControllerTest < ActionDispatch::IntegrationTest
  setup do
    ActionMailbox.ingress = :amazon_ses
    pem_url = "https://sns.eu-west-1.amazonaws.com/SimpleNotificationService-a86cb10b4e1f29c941702d737128f7b6.pem"
    stub_request(:get, pem_url).and_return(body: fixture("certificate.pem"))
  end

  teardown do
    ActionMailbox.ingress = nil
    if Kernel.const_defined? :Aws
      Aws.config[:s3]&.delete(:stub_responses)
    end
  end

  test "receiving an inbound email with an s3 action configured" do
    inbound_s3 = json_fixture("inbound_email_s3")
    s3_email = fixture("s3_email.txt")
    Aws.config[:s3] = {
      stub_responses: {
        head_object: { content_length: s3_email.size, parts_count: 1 },
        get_object: { body: s3_email }
      }
    }

    assert_difference -> { ActionMailbox::InboundEmail.count }, +1 do
      post rails_amazon_ses_inbound_emails_url, params: inbound_s3, as: :json
    end

    assert_response :no_content

    inbound_email = ActionMailbox::InboundEmail.last
    assert_equal s3_email, inbound_email.raw_email.download
  end

  test "accepting subscriptions to recognized topics" do
    recognized_topic = json_fixture("recognized_topic_subscription_request")
    params = {
      Action: "ConfirmSubscription",
      Token: "abcd1234" * 32,
      TopicArn: "arn:aws:sns:eu-west-1:111111111111:recognized-topic"
    }
    request = stub_request(:get, "https://sns.eu-west-1.amazonaws.com/?#{params.to_query}")
    post rails_amazon_ses_inbound_emails_url, params: recognized_topic, as: :json
    assert_requested request
    assert_response :ok
  end

  test "rejecting subscriptions to unrecognized topics" do
    unrecognized_topic = json_fixture("unrecognized_topic_subscription_request")
    url = %r{https://sns.eu-west-1.amazonaws.com/\?Action=ConfirmSubscription}
    request = stub_request(:get, url)
    post rails_amazon_ses_inbound_emails_url, params: unrecognized_topic, as: :json
    assert_not_requested request
    assert_response :unauthorized
  end

  test "rejecting subscriptions with invalid signatures" do
    invalid_signature = json_fixture("invalid_signature")
    url = %r{https://sns.eu-west-1.amazonaws.com/\?Action=ConfirmSubscription}
    request = stub_request(:get, url)
    post rails_amazon_ses_subscriptions_subscribe_url, params: invalid_signature, as: :json
    assert_not_requested request
    assert_response :unauthorized
  end

  test "accepting subscriptions with valid signatures" do
    valid_signature = json_fixture("valid_signature")
    url = %r{https://sns.eu-west-1.amazonaws.com/\?Action=ConfirmSubscription}
    request = stub_request(:get, url)
    post rails_amazon_ses_inbound_emails_url, params: valid_signature, as: :json
    assert_requested request
    assert_response :ok
  end

  private
    def fixture(name)
      file_fixture("../files/amazon/#{name}").read
    end

    def json_fixture(name)
      JSON.parse(fixture("#{name}.json"))
    end
end
