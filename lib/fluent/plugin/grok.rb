require "fluent/plugin/parser_regexp"

module Fluent
  class Grok
    class GrokPatternNotFoundError < StandardError
    end

    # Much of the Grok implementation is based on Jordan Sissel's jls-grok
    # See https://github.com/jordansissel/ruby-grok/blob/master/lib/grok-pure.rb
    PATTERN_RE = \
        /%\{    # match '%{' not prefixed with '\'
           (?<name>     # match the pattern name
             (?<pattern>[A-z0-9]+)
             (?::(?<subname>[@\[\]A-z0-9_:.-]+?)
                  (?::(?<type>(?:string|bool|integer|float|
                                 time(?::.+?)?|
                                 array(?::.)?)))?)?
           )
         \}/x

    attr_reader :parsers
    attr_reader :multiline_start_regexp

    def initialize(plugin, conf)
      @pattern_map = {}
      @parsers = {}
      @multiline_mode = false
      @conf = conf
      @plugin = plugin
      @time_format = nil
      @timezone = nil
      if @plugin.respond_to?(:firstline?)
        @multiline_mode = true
      end
      if @plugin.respond_to?(:multiline_start_regexp) && @plugin.multiline_start_regexp
        @multiline_start_regexp = Regexp.compile(@plugin.multiline_start_regexp[1..-2])
      end
      if @plugin.respond_to?(:keep_time_key)
        @keep_time_key = @plugin.keep_time_key
      end
      if @plugin.respond_to?(:time_format)
        @time_format = @plugin.time_format
      end
      if @plugin.respond_to?(:timezone)
        @timezone = @plugin.timezone
      end
    end

    def add_patterns_from_file(path)
      File.open(path, "r:utf-8:utf-8").each_line do |line|
        next if line[0] == "#" || /^$/ =~ line
        name, pat = line.chomp.split(/\s+/, 2)
        @pattern_map[name] = pat
      end
    end

    def setup
      if @plugin.grok_pattern
        @parsers[:grok_pattern] = expand_pattern_expression_grok_pattern(@plugin.grok_pattern, @conf)
      else
        @plugin.grok_confs.each.with_index do |grok_conf, index|
          @parsers[grok_conf.name || index] = expand_pattern_expression_grok_section(grok_conf)
        end
      end
      @parsers.reject! do |key, parser|
        parser.nil?
      end
      if @parsers.empty?
        raise Fluent::ConfigError, 'no grok patterns. Check configuration, e.g. typo, configuration syntax, etc'
      end
    end

    private

    def expand_pattern_expression_grok_pattern(grok_pattern, conf)
      regexp, types = expand_pattern(grok_pattern)
      $log.info "Expanded the pattern #{grok_pattern} into #{regexp}"
      _conf = conf.to_h
      unless types.empty?
        _conf["types"] = types.map{|subname,type| "#{subname}:#{type}" }.join(",")
      end
      _conf = _conf.merge("expression" => regexp, "multiline" => @multiline_mode, "keep_time_key" => @keep_time_key)
      config = Fluent::Config::Element.new("parse", nil, _conf, [])
      parser = Fluent::Plugin::RegexpParser.new
      parser.configure(config)
      parser
    rescue GrokPatternNotFoundError => e
      raise e
    rescue => e
      $log.error(error: e)
      nil
    end

    def expand_pattern_expression_grok_section(conf)
      regexp, types = expand_pattern(conf.pattern)
      $log.info "Expanded the pattern #{conf.pattern} into #{regexp}"
      _conf = conf.to_h
      unless types.empty?
        _conf["types"] = types.map{|subname,type| "#{subname}:#{type}" }.join(",")
      end
      if conf["multiline"] ||  @multiline_mode
        _conf["multiline"] = conf["multiline"] ||  @multiline_mode
      end
      if conf["keep_time_key"] || @keep_time_key
        _conf["keep_time_key"] = conf["keep_time_key"] || @keep_time_key
      end
      if conf["time_key"]
        _conf["time_key"] = conf["time_key"]
      end
      if conf["time_format"] || @time_format
        _conf["time_format"] = conf["time_format"] || @time_format
      end
      if conf["timezone"] || @timezone
        _conf["timezone"] = conf["timezone"] || @timezone
      end
      _conf["expression"] = regexp
      config = Fluent::Config::Element.new("parse", "", _conf, [])
      parser = Fluent::Plugin::RegexpParser.new
      parser.configure(config)
      parser
    rescue GrokPatternNotFoundError => e
      raise e
    rescue => e
      $log.error(error: e)
      nil
    end

    def expand_pattern(pattern)
      # It's okay to modify in place. no need to expand it more than once.
      type_map = {}
      while true
        m = PATTERN_RE.match(pattern)
        break unless m
        curr_pattern = @pattern_map[m["pattern"]]
        raise GrokPatternNotFoundError, "grok pattern not found: #{pattern}" unless curr_pattern
        if m["subname"]
          ecs = /(?<ecs-key>(^\[.*\]$))/.match(m["subname"])
          subname = if ecs
                      # remove starting "[" and trailing "]" on matched data
                      ecs["ecs-key"][1..-2].split("][").join('.')
                    else
                      m["subname"]
                    end
          replacement_pattern = "(?<#{subname}>#{curr_pattern})"
          type_map[subname] = m["type"] || "string"
        else
          replacement_pattern = "(?:#{curr_pattern})"
        end
        pattern = pattern.sub(m[0]) do |s|
          replacement_pattern
        end
      end

      [pattern, type_map]
    end
  end
end
