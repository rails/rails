desc "Report code statistics (KLOCs, etc) from the application"
task :stats do
  require 'code_statistics'
  CodeStatistics.new(
    ["Helpers", "app/helpers"], 
    ["Controllers", "app/controllers"], 
    ["APIs", "app/apis"],
    ["Components", "components"],
    ["Functionals", "test/functional"],
    ["Models", "app/models"],
    ["Units", "test/unit"]
  ).to_s
end
