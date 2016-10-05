require "fluent/plugin/grok"

module Fluent
  module Plugin
    class GrokPatternNotFoundError < Exception; end

    class GrokParser < Parser
      Fluent::Plugin.register_parser('grok', self)

      # For fluentd v0.12.16 or earlier
      class << self
        unless method_defined?(:desc)
          def desc(description)
          end
        end
      end

      desc 'The format of the time field.'
      config_param :time_format, :string, :default => nil
      desc 'The pattern of grok'
      config_param :grok_pattern, :string, :default => nil
      desc 'Path to the file that includes custom grok patterns'
      config_param :custom_pattern_path, :string, :default => nil

      def initialize
        super
        @default_parser = NoneParser.new
      end

      def configure(conf={})
        super

        @grok = Grok.new(self, conf)

        default_pattern_dir = File.expand_path('../../../../patterns/*', __FILE__)
        Dir.glob(default_pattern_dir) do |pattern_file_path|
          @grok.add_patterns_from_file(pattern_file_path)
        end

        if @custom_pattern_path
          if Dir.exists? @custom_pattern_path
            Dir.glob(@custom_pattern_path + '/*') do |pattern_file_path|
              @grok.add_patterns_from_file(pattern_file_path)
            end
          elsif File.exists? @custom_pattern_path
            @grok.add_patterns_from_file(@custom_pattern_path)
          end
        end

        @grok.setup
      end

      def parse(text, &block)
        if block_given?
          @grok.parsers.each do |parser|
            parser.parse(text) do |time, record|
              if time and record
                yield time, record
                return
              end
            end
          end
          yield @default_parser.parse(text)
        else
          @grok.parsers.each do |parser|
            parser.parse(text) do |time, record|
              if time and record
                return time, record
              end
            end
          end
          return @default_parser.parse(text)
        end
      end
    end
  end
end
