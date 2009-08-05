STDOUT.sync = true

module Rails
  class Git < Scm
    def self.clone(repos, branch=nil)
      system "git clone #{repos}"

      if branch
        system "cd #{repos.split('/').last}/"
        system "git checkout #{branch}"
      end
    end

    def self.run(command)
      system "git #{command}"
    end
  end
end