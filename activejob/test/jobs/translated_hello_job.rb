# frozen_string_literal: true

require_relative "../support/job_buffer"

class TranslatedHelloJob < ActiveJob::Base
  def perform(greeter = "David")
    translations = { en: "Hello", de: "Guten Tag" }
    hello        = translations[I18n.locale]

    JobBuffer.add("#{greeter} says #{hello}")
  end
end
