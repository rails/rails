# frozen_string_literal: true

desc "Copy over the migration, stylesheet, and JavaScript files"
task "action_text:install" do
  Rails::Command.invoke :generate, ["action_text:install"]
end

task "action_text:update" do
  ENV["MIGRATIONS_PATH"] = "db/update_migrate"

  Rails::Command.invoke :generate, ["action_text:install"]
end
