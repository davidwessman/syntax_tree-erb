# frozen_string_literal: true

require "simplecov"
SimpleCov.start

$:.unshift File.expand_path("../lib", __dir__)
require "syntax_tree/erb"

require "minitest/autorun"

class TestCase < Minitest::Test
  def assert_formatting(name)
    directory = File.expand_path("fixture", __dir__)
    unformatted_file = File.join(directory, "#{name}_unformatted.html.erb")
    formatted_file = File.join(directory, "#{name}_formatted.html.erb")

    expected = SyntaxTree::ERB.read(formatted_file)
    formatted = SyntaxTree::ERB.format(SyntaxTree::ERB.read(unformatted_file))

    if (expected != formatted)
      puts("Failed to format #{name}, see ./tmp/#{name}_failed.html.erb")
      Dir.mkdir("./tmp") unless Dir.exist?("./tmp")
      File.write("./tmp/#{name}_failed.html.erb", formatted)
    end

    assert_equal(formatted, expected)
  end
end
