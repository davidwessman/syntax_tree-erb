# frozen_string_literal: true

require "test_helper"

module SyntaxTree
  class HtmlTest < TestCase
    def test_html_wrong_end_tag
      example = <<~HTML
      <div>
        <ul>
          <li>A</li>
          <li>B</li>
          <li>C</li>
          <li>D</li>
      </div>
      HTML
      ERB.parse(example)
    rescue SyntaxTree::Parser::ParseError => error
      assert_equal(7, error.lineno)
      assert_equal(0, error.column)
      assert_match(/Expected closing tag for <ul> but got <div>/, error.message)
    end

    def test_html_no_end_tag
      example = <<~HTML
      <h1>Hello World
      HTML
      ERB.parse(example)
    rescue SyntaxTree::Parser::ParseError => error
      assert_equal(1, error.lineno)
      assert_equal(0, error.column)
      assert_match(/Missing closing tag for <h1>/, error.message)
    end

    def test_html_incorrect_end_tag
      example = <<~HTML
      <div>
      <h1>Hello World</h2>
      </div>
      HTML
      ERB.parse(example)
    rescue SyntaxTree::Parser::ParseError => error
      assert_equal(2, error.lineno)
      assert_equal(15, error.column)
      assert_match(/Expected closing tag for <h1> but got <h2>/, error.message)
    end

    def test_html_unmatched_double_quote
      example = <<~HTML
      <div class="card-"">Hello World</div>
      HTML
      ERB.parse(example)
    rescue SyntaxTree::Parser::ParseError => error
      assert_equal(1, error.lineno)
      assert_equal(31, error.column)
      assert_match(
        /Unexpected character, <, when looking for closing double quote/,
        error.message
      )
    end

    def test_html_unmatched_single_quote
      example = <<~HTML
      <div class='card-''>Hello World</div>
      HTML
      ERB.parse(example)
    rescue SyntaxTree::Parser::ParseError => error
      assert_equal(1, error.lineno)
      assert_equal(31, error.column)
      assert_match(
        /Unexpected character, <, when looking for closing single quote/,
        error.message
      )
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
    end

    def test_html_doctype_duplicate
      example = <<~HTML
      <!DOCTYPE html>
      <h1>Hello World</h1>
      <!DOCTYPE html>
      HTML
      ERB.parse(example)
    rescue SyntaxTree::Parser::ParseError => error
      assert_equal(3, error.lineno)
      assert_equal(0, error.column)
      assert_match(/Duplicate doctype declaration/, error.message)
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

    def test_html_tag_name_at
      ERB.parse("<@br />")
    rescue SyntaxTree::Parser::ParseError => error
      assert_equal(1, error.lineno)
      assert_equal(1, error.column)
      assert_match(/Invalid HTML-tag name @br/, error.message)
    end

    def test_html_tag_name_colon
      ERB.parse("<:br />")
    rescue SyntaxTree::Parser::ParseError => error
      assert_equal(1, error.lineno)
      assert_equal(1, error.column)
      assert_match(/Invalid HTML-tag name :br/, error.message)
    end

    def test_html_tag_name_hash
      ERB.parse("<#br />")
    rescue SyntaxTree::Parser::ParseError => error
      assert_equal(1, error.lineno)
      assert_equal(1, error.column)
      assert_match(/Invalid HTML-tag name #br/, error.message)
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

    def test_self_closing_for_void_elements
      source =
        "<meta name=\"viewport\" content=\"width=device-width,initial-scale=1\" >"
      expected =
        "<meta name=\"viewport\" content=\"width=device-width,initial-scale=1\" />\n"

      assert_formatting(source, expected)
    end
  end
end
