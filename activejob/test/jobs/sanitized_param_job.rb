class SanitizedParamJob < ActiveJob::Base
  def perform(one, two)
    logger.info 'Dummy'
  end

  def arguments_to_log
    result = super.dup
    result[1] = ActiveJob::Logging::SANITIZED_ARG
    result
  end
end
