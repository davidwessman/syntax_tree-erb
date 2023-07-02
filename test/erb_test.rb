# frozen_string_literal: true

require "test_helper"

module SyntaxTree
  class ErbTest < Minitest::Test
    def test_empty_file
      parsed = ERB.parse("")
      assert_instance_of(SyntaxTree::ERB::Document, parsed)
      assert_empty(parsed.elements)
      assert_nil(parsed.location)
    end

    def test_missing_erb_end_tag
      assert_raises(SyntaxTree::ERB::Parser::ParseError) do
        ERB.parse("<% if no_end_tag %>")
      end
    end

    def test_missing_erb_block_end_tag
      assert_raises(SyntaxTree::ERB::Parser::ParseError) do
        ERB.parse("<% no_end_tag do %>")
      end
    end

    def test_erb_code_with_non_ascii
      parsed = ERB.parse("<% \"Påäööööö\" %>")
      assert_equal(1, parsed.elements.size)
      assert_instance_of(SyntaxTree::ERB::ErbNode, parsed.elements.first)
    end

    def test_long_if_statement
      source =
        "<%=number_to_percentage(@reports&.first&.stability*100,precision: 1) if @reports&.first&.other&.stronger&.longer %>\n"
      expected =
        "<%= number_to_percentage(@reports&.first&.stability * 100, precision: 1) if @reports&.first&.other&.stronger&.longer %>\n"

      # With bad formatting, it is not parseable twice
      formatted = ERB.format(source)
      formatted_again = ERB.format(formatted)

      assert_equal(expected, formatted)
      assert_equal(expected, formatted_again)
    end

    def test_text_erb_text
      assert_equal(
        ERB.format(
          "<div>This is some text <%= variable %> and the special value after</div>"
        ),
        "<div>\n  This is some text\n  <%= variable %>\n  and the special value after\n</div>\n"
      )
    end

    def test_erb_with_comment
      source = "<%= what # This is a comment %>\n"

      formatted_once = ERB.format(source)
      formatted_twice = ERB.format(formatted_once)

      assert_equal(source, formatted_once)
      assert_equal(source, formatted_twice)
    end

    def test_erb_only_comment
      source = "<% # This should be written on one line %>\n"
      formatted_once = ERB.format(source)
      formatted_twice = ERB.format(formatted_once)

      assert_equal(source, formatted_once)
      assert_equal(source, formatted_twice)
    end

    def test_erb_ternary_as_argument_without_parentheses
      source =
        "<%=     f.submit f.object.id.present?     ? t('buttons.titles.save'):t('buttons.titles.create')   %>"
      expected =
        "<%= f.submit f.object.id.present? ? t(\"buttons.titles.save\") : t(\"buttons.titles.create\") %>\n"
      formatted = ERB.format(source)

      assert_equal(expected, formatted)
    end
  end
end
