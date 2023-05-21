# frozen_string_literal: true

require "test_helper"

module SyntaxTree
  class FormattingTest < TestCase
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

    def test_vue_components
      assert_formatting("vue_components")
    end

    def test_layout
      assert_formatting("layout")
    end
  end
end
