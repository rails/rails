if RUBY_VERSION < '1.9.3'
  desc = defined?(RUBY_DESCRIPTION) ? RUBY_DESCRIPTION : "ruby #{RUBY_VERSION} (#{RUBY_RELEASE_DATE})"
  abort <<-end_message

    Rails 4 requires Ruby 1.9.3+.

    You're running
      #{desc}

    Please upgrade to continue.

  end_message
end
