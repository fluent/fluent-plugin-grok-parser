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
                                 time(?::.+)?|
                                 array(?:.)?)))?)?
           )
         \}/x

    attr_reader :parsers
    attr_reader :multiline_start_regexp

    def initialize(plugin, conf)
      @pattern_map = {}
      @parsers = []
      @multiline_mode = false
      @conf = conf
      if plugin.respond_to?(:firstline?)
        @multiline_mode = true
      end
      if @conf['multiline_start_regexp']
        @multiline_start_regexp = Regexp.compile(@conf['multiline_start_regexp'][1..-2])
      end
    end

    def add_patterns_from_file(path)
      File.new(path).each_line do |line|
        next if line[0] == '#' || /^$/ =~ line
        name, pat = line.chomp.split(/\s+/, 2)
        @pattern_map[name] = pat
      end
    end

    def setup
      if @conf['grok_pattern']
        @parsers << expand_pattern_expression(@conf['grok_pattern'], @conf)
      else
        grok_confs = @conf.elements.select {|e| e.name == 'grok'}
        grok_confs.each do |grok_conf|
          @parsers << expand_pattern_expression(grok_conf['pattern'], grok_conf)
        end
      end
    end

    private

    def expand_pattern_expression(grok_pattern, conf)
      regexp, types = expand_pattern(grok_pattern)
      $log.info "Expanded the pattern #{conf['grok_pattern']} into #{regexp}"
      options = nil
      if @multiline_mode
        options = Regexp::MULTILINE
      end
      unless types.empty?
        conf["types"] = types.map{|subname,type| "#{subname}:#{type}" }.join(",")
      end
      TextParser::RegexpParser.new(Regexp.new(regexp, options), conf)
    rescue GrokPatternNotFoundError => e
      raise e
    rescue => e
      $log.error e.backtrace.join("\n")
    end

    def expand_pattern(pattern)
      # It's okay to modify in place. no need to expand it more than once.
      type_map = {}
      while true
        m = PATTERN_RE.match(pattern)
        break unless m
        curr_pattern = @pattern_map[m["pattern"]]
        raise GrokPatternNotFoundError unless curr_pattern
        if m["subname"]
          replacement_pattern = "(?<#{m["subname"]}>#{curr_pattern})"
          type_map[m["subname"]] = m["type"] || "string"
        else
          replacement_pattern = curr_pattern
        end
        pattern.sub!(m[0]) do |s| replacement_pattern end
      end

      [pattern, type_map]
    end
  end
end
