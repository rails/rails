require "helper"
require "jobs/translated_hello_job"

class TranslationTest < ActiveSupport::TestCase
  setup do
    JobBuffer.clear
    I18n.available_locales = [:en, :de]
    @job = TranslatedHelloJob.new("Johannes")
  end

  teardown do
    I18n.available_locales = [:en]
  end

  test "it performs the job in the given locale" do
    @job.locale = :de
    @job.perform_now
    assert_equal "Johannes says Guten Tag", JobBuffer.last_value
  end
end
