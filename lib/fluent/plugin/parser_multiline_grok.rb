require "fluent/plugin/parser_grok"

module Fluent
  module Plugin
    class MultilineGrokParser < GrokParser
      Fluent::Plugin.register_parser("multiline_grok", self)

      desc "The regexp to match beginning of multiline"
      config_param :multiline_start_regexp, :string, default: nil

      def has_firstline?
        !!@multiline_start_regexp
      end

      def firstline?(text)
        @multiline_start_regexp && !!@grok.multiline_start_regexp.match(text)
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
