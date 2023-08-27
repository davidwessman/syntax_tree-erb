# frozen_string_literal: true

require "test_helper"

module SyntaxTree
  class ErbTest < TestCase
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

    def test_missing_erb_case_end_tag
      assert_raises(SyntaxTree::ERB::Parser::ParseError) do
        ERB.parse("<% case variabel %>\n<% when 1>\n  Hello\n")
      end
    end

    def test_erb_code_with_non_ascii
      parsed = ERB.parse("<% \"Påäööööö\" %>")
      assert_equal(1, parsed.elements.size)
      assert_instance_of(SyntaxTree::ERB::ErbNode, parsed.elements.first)
    end

    def test_if_and_end_in_same_output_tag_short
      source = "<%= if true\n  what\nend %>"
      expected = "<%= what if true %>\n"

      assert_formatting(source, expected)
    end

    def test_if_and_end_in_same_tag
      source = "<% if true then this elsif false then that else maybe end %>"
      expected =
        "<% if true\n  this\nelsif false\n  that\nelse\n  maybe\nend %>\n"

      assert_formatting(source, expected)
    end

    def test_long_if_statement
      source =
        "<%=number_to_percentage(@reports&.first&.stability*100,precision: 1) if @reports&.first&.other&.stronger&.longer %>"
      expected =
        "<%= if @reports&.first&.other&.stronger&.longer\n  number_to_percentage(@reports&.first&.stability * 100, precision: 1)\nend %>\n"

      assert_formatting(source, expected)
    end

    def test_erb_else_if_statement
      source =
        "<%if this%>\n  <h1>A</h1>\n<%elsif that%>\n  <h1>B</h1>\n<%else%>\n  <h1>C</h1>\n<%end%>"
      expected =
        "<% if this %>\n  <h1>A</h1>\n<% elsif that %>\n  <h1>B</h1>\n<% else %>\n  <h1>C</h1>\n<% end %>\n"

      assert_formatting(source, expected)
    end

    def test_long_ternary
      source =
        "<%= number_to_percentage(@reports&.first&.stability * 100, precision: @reports&.first&.stability ? 'Stable' : 'Unstable') %>"
      expected =
        "<%= number_to_percentage(\n  @reports&.first&.stability * 100,\n  precision: @reports&.first&.stability ? \"Stable\" : \"Unstable\"\n) %>\n"

      assert_formatting(source, expected)
    end

    def test_text_erb_text
      source =
        "<div>This is some text <%= variable %> and the special value after</div>"
      expected =
        "<div>This is some text <%= variable %> and the special value after</div>\n"

      assert_formatting(source, expected)
    end

    def test_erb_with_comment
      source = "<%= what # This is a comment %>\n"

      assert_formatting(source, source)
    end

    def test_erb_only_ruby_comment
      source = "<% # This should be written on one line %>\n"

      assert_formatting(source, source)
    end

    def test_erb_only_erb_comment
      source = "<%# This should be written on one line %>\n"

      assert_formatting(source, source)
    end

    def test_erb_ternary_as_argument_without_parentheses
      source =
        "<%=     f.submit( f.object.id.present?     ? t('buttons.titles.save'):t('buttons.titles.create'))   %>"
      expected =
        "<%= f.submit(\n  f.object.id.present? ? t(\"buttons.titles.save\") : t(\"buttons.titles.create\")\n) %>\n"

      assert_formatting(source, expected)
    end

    def test_erb_whitespace
      source =
        "<%= 1 %>,<%= 2 %>What\n<%= link_to(url) do %><strong>Very long link Very long link Very long link Very long link</strong><% end %>"
      expected =
        "<%= 1 %>,<%= 2 %>What\n<%= link_to(url) do %>\n  <strong>Very long link Very long link Very long link Very long link</strong>\n<% end %>\n"

      assert_formatting(source, expected)
    end

    def test_erb_newline
      source = "<%= what if this %>\n<h1>hej</h1>"
      expected = "<%= what if this %>\n<h1>hej</h1>\n"

      assert_formatting(source, expected)
    end

    def test_erb_group_blank_line
      source = "<%= hello %>\n<%= heya %>\n\n<%# breaks the group %>\n"

      assert_formatting(source, source)
    end

    def test_erb_empty_first_line
      source = "\n\n<%= what %>\n"
      expected = "<%= what %>\n"

      assert_formatting(source, expected)
    end
  end
end
