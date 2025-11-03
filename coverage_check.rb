#!/usr/bin/env ruby
require 'json'

data = JSON.parse(File.read('coverage/.resultset.json'))

data.each do |suite, results|
  puts "\n=== #{suite} ==="

  results['coverage'].keys
    .select { |k| k.include?('lib/simple_authorize') && !k.include?('generators') && !k.include?('railtie') }
    .sort
    .each do |file_path|
      coverage_data = results['coverage'][file_path]

      # Count covered lines (non-nil and > 0)
      # SimpleCov branch coverage uses arrays, so we need to handle both
      covered = coverage_data.compact.count do |v|
        v.is_a?(Array) ? v.any? { |x| x && x > 0 } : v > 0
      end
      # Count relevant lines (non-nil)
      relevant = coverage_data.compact.size

      percentage = relevant > 0 ? (covered.to_f / relevant * 100).round(1) : 0.0

      filename = File.basename(file_path)
      puts "  #{percentage.to_s.rjust(5)}% - #{filename} (#{covered}/#{relevant} lines)"
    end
end

# Calculate overall
all_files = data.values.flat_map { |r| r['coverage'].keys }
  .select { |k| k.include?('lib/simple_authorize') && !k.include?('generators') && !k.include?('railtie') }
  .uniq

puts "\n=== Files Tracked ==="
all_files.sort.each do |f|
  puts "  #{f}"
end
