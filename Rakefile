#!/usr/bin/env rake
require "bundler/gem_tasks"
require "rake/testtask"
require "rake/clean"

task :test => [:base_test]

desc "Run test_unit based test"
Rake::TestTask.new(:base_test) do |t|
  t.libs << "test"
  t.test_files = (Dir["test/test_*.rb"] + Dir["test/plugin/test_*.rb"] - ["helper.rb"]).sort
  t.verbose = true
  # t.warning = false
end

desc "Import patterns from submodules"
task "patterns:import" do
  ["legacy", "ecs-v1"].each do |series|
    `git submodule --quiet foreach pwd`.split($\).each do |submodule_path|
      Dir.glob(File.join(submodule_path, "patterns/#{series}/*")) do |pattern|
        cp(pattern, "patterns/#{series}", verbose: true)
      end
    end
  end

  # copied from "./lib/fluent/plugin/grok"
  pattern_re =
    /%\{    # match '%{' not prefixed with '\'
      (?<name>     # match the pattern name
        (?<pattern>[A-z0-9]+)
        (?::(?<subname>[@\[\]A-z0-9_:.-]+?)
             (?::(?<type>(?:string|bool|integer|float|int|
                            time(?::.+)?|
                            array(?::.)?)))?)?
      )
    \}/x
  ["legacy", "ecs-v1"].each do |series|
    Dir.glob("patterns/#{series}/*") do |pattern_file|
      new_lines = ""
      File.readlines(pattern_file).each do |line|
        case
        when line.strip.empty?
          new_lines << line
        when line.start_with?("#")
          new_lines << line
        else
          name, pattern = line.split(/\s+/, 2)
          new_pattern = pattern.gsub(pattern_re) do |m|
            matched = $~
            if matched[:type] == "int"
              "%{#{matched[:pattern]}:#{matched[:subname]}:integer}"
            else
              m
            end
          end
          new_lines << "#{name} #{new_pattern}"
        end
      end
      File.write(pattern_file, new_lines)
    end
  end
end

task :default => [:test, :build]
