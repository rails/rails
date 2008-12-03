module Rails
  class Git < Scm
    def self.clone(repos, branch=nil)
      `git clone #{repos}`

      if branch
        `cd #{repos.split('/').last}/`
        `git checkout #{branch}`
      end
    end

    def self.run(command)
      `git #{command}`
    end
  end
end