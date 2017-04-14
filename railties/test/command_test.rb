require "isolation/abstract_unit"

class Rails::CommandTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::Isolation

  def setup
    build_app
    create_command
  end

  def teardown
    teardown_app
  end

  test "Rails Help Command prints user created commands in apps" do
    assert_match "Foo:", Dir.chdir(app_path) { `bin/rails help` }
  end

  test "user created command can be executed" do
    assert_match "FooBarFoo!", Dir.chdir(app_path) { `bin/rails foo` }
  end

  private

    def create_command
      Dir.chdir("#{app_path}/app") do
        Dir.mkdir("commands")
        Dir.mkdir("commands/foo")
        Dir.chdir("commands/foo") do
          File.open("foo_command.rb", "w") do |f|
            f.write %q(
              module Foo
                module Command
                  class FooCommand < Rails::Command::Base
                    def foo
                      puts "FooBarFoo!"
                    end
                  end
                end
              end
            )
          end
        end
      end
    end
end
