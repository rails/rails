if RUBY_VERSION < '2.2.0'
  desc = defined?(RUBY_DESCRIPTION) ? RUBY_DESCRIPTION : "ruby #{RUBY_VERSION} (#{RUBY_RELEASE_DATE})"
  abort <<-end_message

    Rails 5 requires to run on Ruby 2.2.0 or newer.

    You're running
      #{desc}

    Please upgrade to Ruby 2.2.0 or newer to continue.

  end_message
end
