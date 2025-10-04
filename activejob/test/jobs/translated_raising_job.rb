# frozen_string_literal: true

require_relative "../support/job_buffer"

class TranslatedRaisingJob < ActiveJob::Base
  rescue_from(StandardError) do
    JobBuffer.add(I18n.locale)
  end

  def perform
    raise "boom"
  end
end
