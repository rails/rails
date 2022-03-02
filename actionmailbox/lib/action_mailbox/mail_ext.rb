# frozen_string_literal: true

require "action_mailbox/mail_with_error_handling"

# The hope is to upstream most of these basic additions to the Mail gem's Mail object. But until then, here they lay!
Dir["#{File.expand_path(File.dirname(__FILE__))}/mail_ext/*"].each { |path| require "action_mailbox/mail_ext/#{File.basename(path)}" }
