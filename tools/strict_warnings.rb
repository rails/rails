# frozen_string_literal: true

$VERBOSE = true
Warning[:deprecated] = true

module RailsStrictWarnings # :nodoc:
  class WarningError < StandardError; end

  PROJECT_ROOT = File.expand_path("../", __dir__)
  ALLOWED_WARNINGS = Regexp.union(
    /circular require considered harmful.*delayed_job/, # Bug in delayed job.
    /circular require considered harmful.*backburner/, # Bug in delayed job.

    # Expected non-verbose warning emitted by Rails.
    /Ignoring .*\.yml because it has expired/,
    /Failed to validate the schema cache because/,
  )

  SUPPRESSED_WARNINGS = Regexp.union(
    # TODO: remove if https://github.com/mikel/mail/pull/1557 or similar fix
    %r{/lib/mail/parsers/.*statement not reached},
    %r{/lib/mail/parsers/.*assigned but unused variable - disp_type_s},
    %r{/lib/mail/parsers/.*assigned but unused variable - testEof},

    # Emitted by zlib
    /attempt to close unfinished zstream/,
  )

  def warn(message, ...)
    return if SUPPRESSED_WARNINGS.match?(message)

    super

    testpath = message[/test\/.*\.rb/]&.chomp || message
    return unless message.include?(PROJECT_ROOT) || Pathname.new(testpath).exist?
    return if ALLOWED_WARNINGS.match?(message)
    return unless ENV["RAILS_STRICT_WARNINGS"] || ENV["BUILDKITE"]

    raise WarningError.new(message)
  end
end

Warning.singleton_class.prepend(RailsStrictWarnings)
