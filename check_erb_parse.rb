#!/bin/ruby

require "syntax_tree/erb"

failures = []

Dir
  .glob("./app/**/*.html.erb")
  .each do |file|
    puts("Processing #{file}")
    begin
      SyntaxTree::ERB.parse(SyntaxTree::ERB.read(file))
    rescue => exception
      failures << {file: file, message: exception.message}
    end
  end

puts failures
