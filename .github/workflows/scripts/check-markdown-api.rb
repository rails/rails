# frozen_string_literal: true

base_sha, head_sha = ARGV

added_files = `git diff --name-only --diff-filter=A #{base_sha}...#{head_sha}`.lines(chomp: true)

abort "Error shelling out to git #{$?}" unless $?.success?

invalid_files = []

added_files.each do |path|
  next unless File.fnmatch?("*/{app,lib}/**/*.rb", path, File::FNM_EXTGLOB | File::FNM_PATHNAME)

  markdown = false

  File.foreach(path, chomp: true) do |line|
    if line == "# :markup: markdown"
      markdown = true
      break
    elsif !line.empty? && !line.start_with?("#")
      break
    end
  end

  invalid_files << path unless markdown
end

if invalid_files.any?
  warn "New Ruby files must use Markdown for their API documentation."
  warn "Please add `# :markup: markdown` at the top of:"
  invalid_files.each do |path|
    warn "  #{path}"
  end

  exit 1
end
