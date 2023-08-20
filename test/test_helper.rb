# frozen_string_literal: true

require "simplecov"
SimpleCov.start

$:.unshift File.expand_path("../lib", __dir__)
require "syntax_tree/erb"

require "minitest/autorun"

class TestCase < Minitest::Test
  def assert_formatting(source, expected)
    formatted = SyntaxTree::ERB.format(source)

    assert_equal(formatted, expected, "Failed first")

    formatted_twice = SyntaxTree::ERB.format(formatted)

    assert_equal(formatted_twice, expected, "Failed second")

    # Check that pretty_print works
    output = SyntaxTree::ERB.parse(expected).pretty_inspect
    refute_predicate(output, :empty?)
  end
end
