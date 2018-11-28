require "fluent/plugin/grok"
require "fluent/plugin/parser_none"

module Fluent
  module Plugin
    class GrokParser < Parser
      Fluent::Plugin.register_parser("grok", self)

      desc "The format of the time field."
      config_param :time_format, :string, default: nil
      desc "The pattern of grok"
      config_param :grok_pattern, :string, default: nil
      desc "Path to the file that includes custom grok patterns"
      config_param :custom_pattern_path, :string, default: nil
      desc "The key has grok failure reason"
      config_param :grok_failure_key, :string, default: nil
      desc "The key name to store grok section's name"
      config_param :grok_name_key, :string, default: nil

      config_section :grok, param_name: "grok_confs", multi: true do
        desc "The name of this grok section"
        config_param :name, :string, default: nil
        desc "The pattern of grok"
        config_param :pattern, :string
        config_param :keep_time_key, :bool, default: false
        config_param :time_key, :string, default: "time"
        config_param :time_format, :string, default: nil
      end

      def initialize
        super
        @default_parser = Fluent::Plugin::NoneParser.new
      end

      def configure(conf={})
        super

        @grok = Grok.new(self, conf)

        default_pattern_dir = File.expand_path("../../../../patterns/*", __FILE__)
        Dir.glob(default_pattern_dir) do |pattern_file_path|
          @grok.add_patterns_from_file(pattern_file_path)
        end

        if @custom_pattern_path
          if Dir.exist? @custom_pattern_path
            Dir.glob(@custom_pattern_path + "/*") do |pattern_file_path|
              @grok.add_patterns_from_file(pattern_file_path)
            end
          elsif File.exist? @custom_pattern_path
            @grok.add_patterns_from_file(@custom_pattern_path)
          end
        end

        @grok.setup
      end

      def parse(text)
        @grok.parsers.each do |name_or_index, parser|
          parser.parse(text) do |time, record|
            if time and record
              record[@grok_name_key] = name_or_index if @grok_name_key
              yield time, record
              return
            end
          end
        end
        @default_parser.parse(text) do |time, record|
          record[@grok_failure_key] = "No grok pattern matched" if @grok_failure_key
          yield time, record
        end
      end
    end
  end
end
