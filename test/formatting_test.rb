# frozen_string_literal: true

require "test_helper"

module SyntaxTree
  class FormattingTest < Minitest::Test
    def test_block
      assert_formatting("block")
    end

    def test_erb_syntax
      assert_formatting("erb_syntax")
    end

    def test_nested_html
      assert_formatting("nested_html")
    end

    def test_if_statements
      assert_formatting("if_statements")
    end

    def test_javascript_frameworks
      assert_formatting("javascript_frameworks")
    end

    def test_case_statements
      assert_formatting("case")
    end

    def test_layout
      assert_formatting("layout")
    end

    private

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

      formatted_twice = SyntaxTree::ERB.format(formatted)
      assert_equal(formatted_twice, expected)

      # Check that pretty_print works
      output = SyntaxTree::ERB.parse(expected).pretty_inspect
      refute_predicate(output, :empty?)
    end
  end
end
