#!/usr/bin/env rake
require "bundler/gem_tasks"
require 'rake/testtask'
require 'rake/clean'

task :test => [:base_test]

desc 'Run test_unit based test'
Rake::TestTask.new(:base_test) do |t|
  t.libs << "test"
  t.test_files = (Dir["test/test_*.rb"] + Dir["test/plugin/test_*.rb"] - ["helper.rb"]).sort
  t.verbose = true
  #t.warning = true
end

desc 'Import patterns from submodules'
task 'patterns:import' do
  `git submodule --quiet foreach pwd`.split($\).each do |submodule_path|
    Dir.glob(File.join(submodule_path, "patterns/*")) do |pattern|
      cp(pattern, "patterns/", verbose: true)
    end
  end
end

task :default => [:test, :build]
