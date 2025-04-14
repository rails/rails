# frozen_string_literal: true

module Rails
  module Generators
    module Db
      module System
        module Change
          module Github
            class CiGenerator < Base # :nodoc:
              class_option :database, enum: Database::DATABASES, type: :string, default: "sqlite3",
                desc: "Include configuration for selected database"

              def edit_ci_yml
                return unless File.exist?(ci_yml_path)

                ci_jobs.each do |job|
                  next if ci_config["jobs"][job].nil?
                  cleanup_job_databases job
                  set_database_service_for job
                  set_database_url_for job
                end

                File.write(ci_yml_path, ci_config_yml)
              end

              private
                def ci_yml_path
                  File.expand_path(".github/workflows/ci.yml", destination_root)
                end

                def database
                  @database ||= Database.build(options[:database])
                end

                def ci_jobs
                  ["test", "system-test"]
                end

                def ci_config
                  @ci_config ||= YAML.load_file(ci_yml_path)
                end

                def cleanup_job_databases(job)
                  if ci_config["jobs"][job]["services"]
                    Database.all.each do |database|
                      ci_config["jobs"][job]["services"].delete(database.name)
                    end
                    if ci_config["jobs"][job]["services"].empty?
                      ci_config["jobs"][job].delete("services")
                    end
                  end
                  if job_step(job)
                    job_step(job)["env"].delete("DATABASE_URL")
                  end
                end

                def set_database_service_for(job)
                  return unless database.ci.service

                  ci_config["jobs"][job]["services"] ||= {}
                  ci_config["jobs"][job]["services"][database.name] = database.ci.service
                  ci_config["jobs"][job] = ci_config["jobs"][job].sort.to_h
                end

                def set_database_url_for(job)
                  return unless database.ci.database_url

                  if job_step(job)
                    job_step(job)["env"]["DATABASE_URL"] = database.ci.database_url
                  end
                end

                def job_step(job)
                  step_name = job == "test" ? "Run tests" : "Run System Tests"
                  ci_config["jobs"][job]["steps"].find { |s| s["name"] == step_name }
                end

                def ci_config_yml
                  ci_config.to_yaml(indentation: 2, line_width: 160)[4..-1].tap do |config|
                    config.sub!(/true:/, "on:")
                  end
                end
            end
          end
        end
      end
    end
  end
end
