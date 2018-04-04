# frozen_string_literal: true

if Gem::Version.new(RUBY_VERSION) < Gem::Version.new("2.4.1") && RUBY_ENGINE == "ruby"
  desc = defined?(RUBY_DESCRIPTION) ? RUBY_DESCRIPTION : "ruby #{RUBY_VERSION} (#{RUBY_RELEASE_DATE})"
  abort <<-end_message

    Rails 6 requires Ruby 2.4.1 or newer.

    You're running
      #{desc}

    Please upgrade to Ruby 2.4.1 or newer to continue.

  end_message
end
