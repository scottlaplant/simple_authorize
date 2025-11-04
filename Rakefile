# frozen_string_literal: true

require "bundler/gem_tasks"
require "minitest/test_task"

Minitest::TestTask.create

require "rubocop/rake_task"

RuboCop::RakeTask.new

begin
  require "yard"
  YARD::Rake::YardocTask.new(:docs) do |t|
    t.files = ["lib/**/*.rb"]
    t.options = ["--output-dir", "docs/api", "--readme", "README.md"]
  end
rescue LoadError
  # YARD not available
end

task default: %i[test rubocop]
