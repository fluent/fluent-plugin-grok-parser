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
             (?::(?<subname>[@\[\]A-z0-9_:.-]+))?
           )
         \}/x

    attr_reader :parsers

    def initialize(plugin, conf)
      @pattern_map = {}
      @parsers = []
      @multiline_mode = false
      @conf = conf
      if plugin.instance_of?(Fluent::TextParser::MultilineGrokParser)
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
        if @multiline_mode
          patterns = grok_confs.map do |grok_conf|
            expand_pattern(grok_conf['pattern'])
          end
          regexp = Regexp.new(patterns.join, Regexp::MULTILINE)
          @parsers << TextParser::RegexpParser.new(regexp, @conf)
        else
          grok_confs.each do |grok_conf|
            @parsers << expand_pattern_expression(grok_conf['pattern'], grok_conf)
          end
        end
      end
    end

    private

    def expand_pattern_expression(grok_pattern, conf)
      regexp = expand_pattern(grok_pattern)
      $log.info "Expanded the pattern #{conf['grok_pattern']} into #{regexp}"
      options = nil
      if @multiline_mode
        options = Regexp::MULTILINE
      end
      TextParser::RegexpParser.new(Regexp.new(regexp, options), conf)
    rescue GrokPatternNotFoundError => e
      raise e
    rescue => e
      $log.error e.backtrace.join("\n")
    end

    def expand_pattern(pattern)
      # It's okay to modify in place. no need to expand it more than once.
      while true
        m = PATTERN_RE.match(pattern)
        break unless m
        curr_pattern = @pattern_map[m["pattern"]]
        raise GrokPatternNotFoundError unless curr_pattern
        replacement_pattern = if m["subname"]
                                "(?<#{m["subname"]}>#{curr_pattern})"
                              else
                                curr_pattern
                              end
        pattern.sub!(m[0]) do |s| replacement_pattern end
      end

      pattern
    end
  end
end
