# frozen_string_literal: true

desc "Copy over the migration, stylesheet, and JavaScript files"
task "action_text:install" do
  Rails::Command.invoke :generate, ["action_text:install"]
end

task "action_text:install:api" do
  Rails::Command.invoke :generate, ["action_text:install", "--api"]
end
