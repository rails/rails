# frozen_string_literal: true

module ChdirHelpers
  private
    def chdir(dir)
      pwd = Dir.pwd
      Dir.chdir(dir)
      yield
    ensure
      Dir.chdir(pwd)
    end
end
