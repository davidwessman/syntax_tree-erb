# frozen_string_literal: true

require "test_helper"

module SyntaxTree
  class ERBTest < Minitest::Test
    def test_block
      assert_parsing("block")
    end

    def test_erb_syntax
      assert_parsing("erb_syntax")
    end

    def test_nested_html
      assert_parsing("nested_html")
    end

    def test_if_statements
      assert_parsing("if_statements")
    end

    def test_vue_components
      assert_parsing("vue_components")
    end

    def test_layout
      assert_parsing("layout")
    end

    def test_empty_file
      parsed = ERB.parse("")
      assert_instance_of(SyntaxTree::ERB::Document, parsed)
      assert_empty(parsed.elements)
      assert_nil(parsed.location)
    end

    def test_invalid_file
      assert_raises(SyntaxTree::ERB::Parser::ErbKeywordError) do
        ERB.parse("<% if no_end_tag %>")
      end
    end

    private

    def assert_parsing(name)
      directory = File.expand_path("fixture", __dir__)
      unformatted_file = File.join(directory, "#{name}_unformatted.html.erb")
      formatted_file = File.join(directory, "#{name}_formatted.html.erb")

      expected = ERB.read(formatted_file)
      formatted = ERB.format(ERB.read(unformatted_file))

      if (expected != formatted)
        puts("Failed to format #{name}, see ./tmp/#{name}_failed.html.erb")
        Dir.mkdir("./tmp") unless Dir.exist?("./tmp")
        File.write("./tmp/#{name}_failed.html.erb", formatted)
      end

      assert_equal(formatted, expected)
    end
  end
end
