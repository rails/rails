# frozen_string_literal: true

$VERBOSE = true
Warning[:deprecated] = true

module RaiseWarnings
  PROJECT_ROOT = File.expand_path("../../../../", __dir__)
  ALLOWED_WARNINGS = Regexp.union(
    /circular require considered harmful.*delayed_job/, # Bug in delayed job.

    # Expected non-verbose warning emitted by Rails.
    /Ignoring .*\.yml because it has expired/,
    /Failed to validate the schema cache because/,
  )
  def warn(message, *)
    super

    return unless message.include?(PROJECT_ROOT)
    return if ALLOWED_WARNINGS.match?(message)
    return unless ENV["RAILS_STRICT_WARNINGS"] || ENV["CI"]

    raise message
  end
  ruby2_keywords :warn if respond_to?(:ruby2_keywords, true)
end

Warning.singleton_class.prepend(RaiseWarnings)
