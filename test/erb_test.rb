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
      example = <<~HTML
      <ul>
        <% if condition %>
          <li>A</li>
          <li>B</li>
          <li><%= "C" %></li>
      </ul>
      HTML
      ERB.parse(example)
    rescue SyntaxTree::Parser::ParseError => error
      assert_equal(2, error.lineno)
      assert_equal(2, error.column)
      assert_match(/No matching ERB-tag for the <% if %>/, error.message)
    end

    def test_missing_erb_block_end_tag
      example = <<~HTML
      <% no_end_tag do %>
        <h1>What</h1>
      HTML
      ERB.parse(example)
    rescue SyntaxTree::Parser::ParseError => error
      assert_equal(1, error.lineno)
      assert_equal(0, error.column)
      assert_match(/No matching <% end %> for the <% do %>/, error.message)
    end

    def test_missing_erb_case_end_tag
      example = <<~HTML
      <% case variabel %>
      <% when 1 %>
        Hello
      <% when 2 %>
        World
      <h1>What</h1>
      HTML
      ERB.parse(example)
    rescue SyntaxTree::Parser::ParseError => error
      assert_equal(4, error.lineno)
      assert_equal(0, error.column)
      assert_match(/No matching ERB-tag for the <% when %>/, error.message)
    end

    def test_erb_code_with_non_ascii
      parsed = ERB.parse("<% \"Påäööööö\" %>")
      assert_equal(1, parsed.elements.size)
      assert_instance_of(SyntaxTree::ERB::ErbNode, parsed.elements.first)
    end

    def test_erb_syntax_error
      example = <<~HTML
      <ul>
        <% if @items.each do |i| %>
          <li><%= i %></li>
        <% end.blank? %>
          <li>No items</li>
        <% end %>
      </ul>
      HTML
      ERB.parse(example)
    rescue SyntaxTree::Parser::ParseError => error
      assert_equal(4, error.lineno)
      assert_equal(7, error.column)
      assert_match(/Could not parse ERB-tag/, error.message)
    end

    def test_erb_syntax_error2
      example = <<~HTML
      <%= content_tag :header do %>
        <div class="flex-1 min-w-0">
          <h2>
            <%= yield :page_header %>
          </h2>
          <%= content_tag :div do %>
            <%= yield :page_subheader %>
          <% end if content_for?(:page_subheader) %>
        </div>
        <%= content_tag :div do %>
          <%= yield :page_actions %>
        <% end if content_for?(:page_actions) %>
      <% end if content_for?(:page_header) %>
      HTML
      ERB.parse(example)
    rescue SyntaxTree::Parser::ParseError => error
      assert_equal(8, error.lineno)
      assert_equal(9, error.column)
      assert_match(/Could not parse ERB-tag/, error.message)
    end

    def test_if_and_end_in_same_output_tag_short
      source = "<%= if true\n  what\nend %>"
      expected = "<%= what if true %>\n"

      assert_formatting(source, expected)
    end

    def test_if_and_end_in_same_tag
      source =
        "Hello\n<% if true then this elsif false then that else maybe end %>\n<h1>Hey</h1>"
      expected = <<~EXPECTED
        Hello
        <%
          if true
            this
          elsif false
            that
          else
            maybe
          end
        %>
        <h1>Hey</h1>
      EXPECTED

      assert_formatting(source, expected)
    end

    def test_erb_output_inside_html_tag
      source = "<div <%= if eeee then \"b\" else c end %>></div>"
      expected = "<div <%= eeee ? \"b\" : c %>></div>\n"

      assert_formatting(source, expected)
    end

    def test_erb_if_inside_html_tag
      source = "<div <% if eeee %>b<% else %><%= c %><% end %>></div>"
      expected = "<div <% if eeee %>b<% else %><%= c %><% end %>></div>\n"

      assert_formatting(source, expected)
    end

    def test_erb_output_inside_html_attribute_value
      source = "<div class='foo <%= some_class %>'></div>"
      expected = "<div class=\"foo <%= some_class %>\"></div>\n"

      assert_formatting(source, expected)
    end

    def test_erb_if_inside_html_attribute_value
      source =
        "<div class='foo <% if a %>b<%    else %><%= c %><% end %>'></div>"
      expected =
        "<div class=\"foo <% if a %>b<% else %><%= c %><% end %>\"></div>\n"

      assert_formatting(source, expected)
    end

    def test_long_if_statement
      source =
        "<%=number_to_percentage(@reports&.first&.stability*100,precision: 1) if @reports&.first&.other&.stronger&.longer %>"
      expected = <<~EXPECTED
        <%=
          if @reports&.first&.other&.stronger&.longer
            number_to_percentage(@reports&.first&.stability * 100, precision: 1)
          end
        %>
      EXPECTED

      assert_formatting(source, expected)
    end

    def test_erb_else_if_statement
      source =
        "<%if this%>\n  <h1>A</h1>\n<%elsif that%>\n  <h1>B</h1>\n<%else%>\n  <h1>C</h1>\n<%end%>"
      expected = <<~EXPECTED
        <% if this %>
          <h1>A</h1>
        <% elsif that %>
          <h1>B</h1>
        <% else %>
          <h1>C</h1>
        <% end %>
      EXPECTED

      assert_formatting(source, expected)
    end

    def test_long_ternary
      source =
        "<%= number_to_percentage(@reports&.first&.stability * 100, precision: @reports&.first&.stability ? 'Stable' : 'Unstable') %>"
      expected = <<~EXPECTED
        <%=
          number_to_percentage(
            @reports&.first&.stability * 100,
            precision: @reports&.first&.stability ? "Stable" : "Unstable"
          )
        %>
      EXPECTED

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

    def test_erb_comment
      source = "<%# This should be written on one line %>\n"

      assert_formatting(source, source)
    end

    def test_erb_multiline_comment
      source =
        "<%#\n  This is the first\n     This is the second\n    This is the third %>"
      expected =
        "<%#\nThis is the first\nThis is the second\nThis is the third %>\n"

      assert_formatting(source, expected)
    end

    def test_erb_ternary_as_argument_without_parentheses
      source =
        "<%=     f.submit( f.object.id.present?     ? t('buttons.titles.save'):t('buttons.titles.create'))   %>"
      expected = <<~EXPECTED
        <%=
          f.submit(
            f.object.id.present? ? t("buttons.titles.save") : t("buttons.titles.create")
          )
        %>
      EXPECTED

      assert_formatting(source, expected)
    end

    def test_erb_whitespace
      source =
        "<%= 1 %>,<%= 2 %>What\n<%= link_to(url) do %><strong>Very long link Very long link Very long link Very long link</strong><% end %>"
      expected =
        "<%= 1 %>,<%= 2 %>What\n<%= link_to(url) do %>\n  <strong>Very long link Very long link Very long link Very long link</strong>\n<% end %>\n"

      assert_formatting(source, expected)
    end

    def test_erb_block_do_arguments
      source = "<%= link_to(url) do |link, other_arg|%>Whaaaaaaat<% end %>"
      expected =
        "<%= link_to(url) do |link, other_arg| %>\n  Whaaaaaaat\n<% end %>\n"

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

    def test_parsing_column_position
      example = <<~HTML
      <ul>
        <% if condition %>
          <li>A</li>
        <% end %>
        <!-- Comment
        about something and other
        --><%= yes %>
      </ul>
      HTML
      parsed = ERB.parse(example)
      elements = parsed.elements

      assert_equal(1, elements.size)

      ul = elements.first

      assert_equal(1, ul.location.start_line)
      assert_equal(8, ul.location.end_line)
      assert_equal(0, ul.location.start_char)
      assert_equal(0, ul.location.start_column)
      assert_equal(5, ul.location.end_column)
      assert_equal(3, ul.elements.size)

      if_node = ul.elements.first

      assert_equal(2, if_node.location.start_line)
      assert_equal(4, if_node.location.end_line)
      assert_equal(2, if_node.location.start_column)

      comment_node = ul.elements[1]

      assert_equal(5, comment_node.location.start_line)
      assert_equal(7, comment_node.location.end_line)
      assert_equal(2, comment_node.location.start_column)
      assert_equal(6, comment_node.location.end_column)
    end
  end
end
