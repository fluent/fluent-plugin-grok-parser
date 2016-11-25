require "fluent/plugin/grok"

module Fluent
  module Plugin
    class GrokParser < Parser
      Fluent::Plugin.register_parser("grok", self)

      desc "The format of the time field."
      config_param :time_format, :string, default: nil
      desc "The pattern of grok"
      config_param :grok_pattern, :string, default: nil, deprecated: true
      desc "Path to the file that includes custom grok patterns"
      config_param :custom_pattern_path, :string, default: nil

      def initialize
        super
        @default_parser = NoneParser.new
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
        @grok.parsers.each do |parser|
          parser.parse(text) do |time, record|
            if time and record
              yield time, record
              return
            end
          end
        end
        @default_parser.parse(text) do |time, record|
          yield time, record
        end
      end
    end
  end
end
