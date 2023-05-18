# frozen_string_literal: true

require "test_helper"

module SyntaxTree
  class ERBTest < Minitest::Test
    def test_block
      assert_parsing("block")
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
