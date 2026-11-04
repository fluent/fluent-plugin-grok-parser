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
    end
  end
end
