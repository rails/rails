min_release  = "1.8.7"
ruby_release = "#{RUBY_VERSION} (#{RUBY_RELEASE_DATE})"
if ruby_release < min_release
  abort <<-end_message

    Rails requires Ruby version #{min_release} or later.
    You're running #{ruby_release}; please upgrade to continue.

  end_message
end
