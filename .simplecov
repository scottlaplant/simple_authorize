# frozen_string_literal: true

SimpleCov.start do
  add_filter "/test/"
  add_filter "/spec/"
  add_filter "/lib/generators/"
  add_filter "/lib/simple_authorize/railtie.rb"

  # Merge results from multiple test runs
  use_merging true
  merge_timeout 3600 # 1 hour

  # Don't enforce minimum yet
  # minimum_coverage line: 95, branch: 90
end
