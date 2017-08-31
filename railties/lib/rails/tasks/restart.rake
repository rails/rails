# frozen_string_literal: true

desc "Restart app by touching tmp/restart.txt"
task :restart do
  verbose(false) do
    mkdir_p "tmp"
    touch "tmp/restart.txt"
  end
end
