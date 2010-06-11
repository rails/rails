ruby_release = "#{RUBY_VERSION} (#{RUBY_RELEASE_DATE})"
if ruby_release < '1.8.7' || (ruby_release > '1.8' && ruby_release < '1.9.2')
  abort <<-end_message

    Rails 3 requires Ruby 1.8.7 or 1.9.2.

    You're running #{ruby_release}; please upgrade to continue.

  end_message
end
