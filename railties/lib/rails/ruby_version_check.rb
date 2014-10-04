if RUBY_VERSION < '1.9.3'
  desc = defined?(RUBY_DESCRIPTION) ? RUBY_DESCRIPTION : "ruby #{RUBY_VERSION} (#{RUBY_RELEASE_DATE})"
  abort <<-end_message

    Rails 4 prefers to run on Ruby 2.1 or newer.

    You're running
      #{desc}

    Please upgrade to Ruby 1.9.3 or newer to continue.

  end_message
end
