# frozen_string_literal: true

desc "Install Action Mailbox and its dependencies"
task "action_mailbox:install" do
  Rails::Command.invoke :generate, ["action_mailbox:install"]
end
