# frozen_string_literal: true

require "test_helper"

module SyntaxTree
  class HtmlTest < TestCase
    def test_html_missing_end_tag
      assert_raises(SyntaxTree::ERB::Parser::ParseError) do
        ERB.parse("<h1>Hello World")
      end
    end

    def test_html_incorrect_end_tag
      assert_raises(SyntaxTree::ERB::Parser::ParseError) do
        ERB.parse("<h1>Hello World</h2>")
      end
    end

    def test_html_unmatched_double_quote
      assert_raises(SyntaxTree::ERB::Parser::ParseError) do
        ERB.parse("<div class=\"card-\"\">Hello World</div>")
      end
    end

    def test_html_unmatched_single_quote
      assert_raises(SyntaxTree::ERB::Parser::ParseError) do
        ERB.parse("<div class='card-''>Hello World</div>")
      end
    end

    def test_empty_file
      source = ""
      assert_formatting(source, "\n")
    end

    def test_html_doctype
      parsed = ERB.parse("<!DOCTYPE html>")
      assert_instance_of(SyntaxTree::ERB::Doctype, parsed.elements.first)

      parsed = ERB.parse("<!doctype html>")
      assert_instance_of(SyntaxTree::ERB::Doctype, parsed.elements.first)

      # Allow doctype to not be the first element
      parsed = ERB.parse("<% theme = \"general\" %> <!DOCTYPE html>")
      assert_equal(2, parsed.elements.size)
      assert_equal(
        [SyntaxTree::ERB::ErbNode, SyntaxTree::ERB::Doctype],
        parsed.elements.map(&:class)
      )

      # Do not allow multiple doctype elements
      assert_raises(SyntaxTree::ERB::Parser::ParseError) do
        ERB.parse("<!DOCTYPE html>\n<!DOCTYPE html>\n")
      end
    end

    def test_html_comment
      source = "<!-- This is a HTML-comment -->\n"
      parsed = ERB.parse(source)
      elements = parsed.elements
      assert_equal([SyntaxTree::ERB::HtmlComment], elements.map(&:class))

      assert_formatting(source, source)
    end

    def test_html_within_quotes
      source =
        "<p>This is our text \"<strong><%= @object.quote %></strong>\"</p>"
      parsed = ERB.parse(source)
      elements = parsed.elements

      assert_equal(1, elements.size)
      assert_instance_of(SyntaxTree::ERB::HtmlNode, elements.first)
      elements = elements.first.elements

      assert_equal("This is our text \"", elements.first.value.value)
      assert_equal("\"", elements.last.value.value)
    end

    def test_html_tag_names
      assert_raises(SyntaxTree::ERB::Parser::ParseError) do
        ERB.parse("<@br />")
      end
      assert_raises(SyntaxTree::ERB::Parser::ParseError) do
        ERB.parse("<:br />")
      end
      assert_raises(SyntaxTree::ERB::Parser::ParseError) do
        ERB.parse("<#br />")
      end
    end

    def test_html_attribute_without_quotes
      source = "<div class=card>Hello World</div>"
      parsed = ERB.parse(source)
      elements = parsed.elements

      assert_equal(1, elements.size)
      assert_instance_of(SyntaxTree::ERB::HtmlNode, elements.first)
      assert_equal(1, elements.first.opening.attributes.size)

      attribute = elements.first.opening.attributes.first
      assert_equal("class", attribute.key.value)
      assert_equal("card", attribute.value.contents.first.value)

      expected = "<div class=\"card\">Hello World</div>\n"
      assert_formatting(source, expected)
    end

    def test_empty_component_without_attributes
      source = "<component-without-content>\n</component-without-content>\n"
      expected = "<component-without-content></component-without-content>\n"

      assert_formatting(source, expected)
    end

    def test_empty_component_with_attributes
      source =
        "<three-word-component :allowed-words=\"['first', 'second', 'third', 'fourth']\" :disallowed-words=\"['fifth', 'sixth']\" >\n</three-word-component>"
      expected =
        "<three-word-component\n  :allowed-words=\"['first', 'second', 'third', 'fourth']\"\n  :disallowed-words=\"['fifth', 'sixth']\"\n></three-word-component>\n"
      assert_formatting(source, expected)
    end

    def test_keep_lines_with_text_in_block
      source = "<h2>Hello <%= @football_team_membership.user %>,</h2>"
      expected = "<h2>Hello <%= @football_team_membership.user %>,</h2>\n"

      assert_formatting(source, expected)
    end

    def test_keep_lines_with_text_in_block_in_document
      source = "Hello <span>Name</span>!"
      expected = "Hello <span>Name</span>!\n"
      assert_formatting(source, expected)
    end

    def test_keep_lines_with_nested_html
      source = "<div>Hello <span>Name</span>!</div>"
      expected = "<div>Hello <span>Name</span>!</div>\n"
      assert_formatting(source, expected)
    end

    def test_newlines
      source = "Hello\n\n\n\nGoodbye!\n"
      expected = "Hello\n\nGoodbye!\n"

      assert_formatting(source, expected)
    end

    def test_indentation
      source =
        "<div>\n    <div>\n     <div>\nWhat\n</div>\n     </div>\n  </div>\n"

      expected = "<div>\n  <div>\n    <div>What</div>\n  </div>\n</div>\n"

      assert_formatting(source, expected)
    end

    def test_append_newlines
      source = "<div>\nWhat\n</div>"
      parsed = ERB.parse(source)

      assert_equal(1, parsed.elements.size)
      html = parsed.elements.first

      refute_nil(html.opening.new_line)
      refute_nil(html.elements.first.new_line)
      assert_nil(html.closing.new_line)

      assert_formatting(source, "<div>What</div>\n")
      assert_formatting("<div>What</div>", "<div>What</div>\n")
    end

    def test_self_closing_with_blank_line
      source =
        "<meta http-equiv=\"Content-Type\" content=\"text/html; charset=UTF-8\" />\n\n<title>Test</title>\n"

      assert_formatting(source, source)
    end

    def test_tag_with_leading_and_trailing_spaces
      source = "<div>   What   </div>"
      expected = "<div>What</div>\n"
      assert_formatting(source, expected)
    end

    def test_tag_with_leading_and_trailing_spaces_erb
      source = "<div>   <%=user.name%>   </div>"
      expected = "<div><%= user.name %></div>\n"
      assert_formatting(source, expected)
    end

    def test_breakable_on_char_data_white_space
      source =
        "You have been removed as a user from <strong><%= @company.title %></strong> by <%= @administrator.name %>."
      expected =
        "You have been removed as a user from <strong>\n  <%= @company.title %>\n</strong> by <%= @administrator.name %>.\n"

      assert_formatting(source, expected)
    end

    def test_self_closing_group
      source = "<link />\n<link />\n<meta />"
      expected = "<link />\n<link />\n<meta />\n"

      assert_formatting(source, expected)
    end
  end
end
