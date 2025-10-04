# frozen_string_literal: true

require "net/http"
require "json"
require "uri"

def versions_section(advisory)
  desc = +""
  advisory[:vulnerabilities].each do |vuln|
    package = vuln[:package][:name]
    bad_versions = vuln[:vulnerable_version_range]
    patched_versions = vuln[:patched_versions]
    desc << "* #{package} #{bad_versions}"
    desc << " (patched in #{patched_versions})" unless patched_versions.empty?
    desc << "\n"
  end
  ["Versions affected", desc]
end

def patches_section(advisory)
  desc = +""
  advisory[:vulnerabilities].each do |vuln|
    patched_versions = vuln[:patched_versions]
    commit = IO.popen(%W[git log --format=format:%H --grep=#{advisory[:cve_id]} v#{patched_versions}], &:read)
    raise "git log failed" unless $?.success?
    branch = patched_versions[/^\d+\.\d+/]
    desc << "* #{branch} - https://github.com/rails/rails/commit/#{commit}.patch\n"
  end
  ["Patches", desc]
end

def format_advisory(advisory)
  text = advisory[:description].dup
  text.gsub!("\r\n", "\n") # yuck

  sections = text.split(/(?=\n[A-Z].+\n---+\n)/)
  header = sections.shift.strip
  header = <<EOS
#{header}

* #{advisory[:cve_id]}
* #{advisory[:ghsa_id]}

EOS

  sections.map! do |section|
    section.split(/^---+$/, 2).map(&:strip)
  end

  sections.unshift(versions_section(advisory))
  sections.push(patches_section(advisory))

  ([header.strip] + sections.map do |section|
    title, body = section
    "#{title}\n#{"-" * title.size}\n#{body.strip}"
  end).join("\n\n")
end

uri = URI("https://api.github.com/repos/rails/rails/security-advisories")
json = Net::HTTP.get(uri)
advisories = JSON.parse(json, symbolize_names: true)

should_open = ARGV.delete("--open")
cves = ARGV
unless cves.any? && cves.all? { |s| s.match?(/\ACVE-\d\d\d\d-\d+\z/) }
  puts "Usage: #$0 CVE-YYYY-XXXXX..."
  puts
  puts "recent CVEs:"
  advisories[0, 10].each do |advisory|
    puts "  #{advisory[:cve_id]} - #{advisory[:summary]}"
  end
  exit 1
end

cves.map do |cve|
  advisory = advisories.detect { |x| x[:cve_id] == cve }
  raise "Can't find #{cve}" unless advisory
  if should_open
    format = format_advisory(advisory)
    query = {
      title: "[#{advisory[:cve_id]}] #{advisory[:summary]}",
      body: format,
      category: "security-announcements",
      tags: "announcement,security"
    }
    url = "https://discuss.rubyonrails.org/new-topic?#{URI.encode_www_form(query)}"
    system(ENV.fetch("BROWSER", "open"), url)
  else
    puts "# #{advisory[:summary]}"
    puts
    puts format_advisory(advisory)
  end
end
