# frozen_string_literal: true

require "helper"
require "jobs/translated_hello_job"
require "jobs/translated_raising_job"

class TranslationTest < ActiveSupport::TestCase
  setup do
    JobBuffer.clear
    I18n.available_locales = [:en, :de]
  end

  teardown do
    I18n.available_locales = [:en]
  end

  test "it performs the job in the given locale" do
    job = TranslatedHelloJob.new("Johannes")
    job.locale = :de
    job.perform_now
    assert_equal "Johannes says Guten Tag", JobBuffer.last_value
  end

  test "it runs the exception handler in the given locale" do
    job = TranslatedRaisingJob.new
    job.locale = :de
    job.perform_now
    assert_equal :de, JobBuffer.last_value
  end
end
