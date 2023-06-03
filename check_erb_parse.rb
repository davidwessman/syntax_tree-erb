#!/bin/ruby

require "syntax_tree/erb"

failures = []

Dir
  .glob("./app/**/*.html.erb")
  .each do |file|
    puts("Processing #{file}")
    begin
      source = SyntaxTree::ERB.read(file)
      SyntaxTree::ERB.parse(source)
      SyntaxTree::ERB.format(source)
    rescue => exception
      failures << { file: file, message: exception.message }
    end
  end

puts failures
