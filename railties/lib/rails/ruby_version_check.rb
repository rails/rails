if RUBY_VERSION < '1.9.2'
  desc = defined?(RUBY_DESCRIPTION) ? RUBY_DESCRIPTION : "ruby #{RUBY_VERSION} (#{RUBY_RELEASE_DATE})"
  abort <<-end_message

    Rails 3.1 requires Ruby 1.9.2 or higher.

    You're running
      #{desc}

    Please upgrade to continue.

  end_message
end
