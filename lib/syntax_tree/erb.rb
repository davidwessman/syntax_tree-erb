# frozen_string_literal: true

require "prettier_print"
require "syntax_tree"

require_relative "erb/nodes"
require_relative "erb/parser"
require_relative "erb/visitor"

require_relative "erb/format"
require_relative "erb/pretty_print"

module SyntaxTree
  module ERB
    MAX_WIDTH = 80
    def self.format(source, maxwidth = MAX_WIDTH, options: nil)
      PrettierPrint.format(+"", maxwidth) { |q| parse(source).format(q) }
    end

    def self.parse(source)
      Parser.new(source).parse
    end

    def self.read(filepath)
      File.read(filepath)
    end
  end

  register_handler(".erb", ERB)
end
