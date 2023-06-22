# frozen_string_literal: true

module SyntaxTree
  module ERB
    class Format < Visitor
      attr_reader :q

      def initialize(q)
        @q = q
      end

      # Visit a Token node.
      def visit_token(node)
        q.text(node.value.strip)
      end

      # Visit a Document node.
      def visit_document(node)
        child_nodes = node.child_nodes.sort_by(&:location)

        q.seplist(child_nodes, -> { q.breakable(force: true) }) do |child_node|
          visit(child_node)
        end

        q.breakable(force: true)
      end

      def visit_block(node)
        visit(node.opening)

        if node.elements.any?
          q.indent do
            q.breakable("")
            q.seplist(
              node.elements,
              -> { q.breakable(force: true) }
            ) { |child_node| visit(child_node) }
          end
        end

        if node.closing
          q.breakable("")
          visit(node.closing)
        end
      end

      def visit_html(node)
        visit_block(node)
      end

      def visit_erb_block(node)
        visit_block(node)
      end

      def visit_erb_if(node)
        visit_block(node)
      end

      def visit_erb_elsif(node)
        visit_block(node)
      end

      def visit_erb_else(node)
        visit_block(node)
      end

      def visit_erb_case(node)
        visit_block(node)
      end

      def visit_erb_case_when(node)
        visit_block(node)
      end

      # Visit an ErbNode node.
      def visit_erb(node)
        visit(node.opening_tag)

        if node.keyword
          q.text(" ")
          visit(node.keyword)
        end

        visit(node.content)

        visit(node.closing_tag)
      end

      def visit_erb_do_close(node)
        visit(node.closing)
      end

      def visit_erb_close(node)
        visit(node.closing)
      end

      # Visit an ErbEnd node.
      def visit_erb_end(node)
        visit(node.opening_tag)
        q.text(" ")
        visit(node.keyword)
        q.text(" ")
        visit(node.closing_tag)
      end

      def visit_erb_content(node)
        rows =
          if node.value.is_a?(String)
            node.value.split("\n")
          else
            formatter =
              SyntaxTree::Formatter.new("", [], erb_print_width(node.value))
            formatter.format(node.value.statements)
            formatter.flush
            formatter.output.join.split("\n")
          end

        if rows.size > 1
          q.group do
            q.text(" ")
            q.seplist(rows, -> { q.breakable(" ") }) { |row| q.text(row) }
            q.text(" ")
          end
        elsif rows.size == 1
          q.text(" ")
          q.text(rows.first)
          q.text(" ")
        else
          q.text(" ")
        end
      end

      # Visit an HtmlNode::OpeningTag node.
      def visit_opening_tag(node)
        q.group do
          visit(node.opening)
          visit(node.name)

          if node.attributes.any?
            q.indent do
              q.breakable
              q.seplist(node.attributes, -> { q.breakable }) do |child_node|
                visit(child_node)
              end
            end
          end

          q.breakable(node.closing.value == "/>" ? " " : "")
          visit(node.closing)
        end
      end

      # Visit an HtmlNode::ClosingTag node.
      def visit_closing_tag(node)
        q.group do
          visit(node.opening)
          visit(node.name)
          visit(node.closing)
        end
      end

      # Visit an Attribute node.
      def visit_attribute(node)
        q.group do
          visit(node.key)
          visit(node.equals)
          visit(node.value)
        end
      end

      # Visit a HtmlString node.
      def visit_html_string(node)
        q.group do
          q.text("\"")
          q.seplist(node.contents, -> { "" }) { |child_node| visit(child_node) }
          q.text("\"")
        end
      end

      def visit_html_comment(node)
        visit(node.token)
      end

      # Visit a CharData node.
      def visit_char_data(node)
        lines = node.value.value.strip.split("\n")

        if lines.size > 0
          q.seplist(lines, -> { q.breakable(indent: false) }) do |line|
            q.text(line)
          end
        end
      end

      # Visit a Doctype node.
      def visit_doctype(node)
        q.group do
          visit(node.opening)
          q.text(" ")
          visit(node.name)

          visit(node.closing)
        end
      end

      def erb_print_width(syntax_tree)
        statements = syntax_tree.statements.body
        # Set the width to maximum if we have an IfNode or IfOp,
        # we cannot format them purely with SyntaxTree because the ERB-syntax will be unparseable.
        if statements.any? { |node| check_for_if_statement(node) }
          999_999
        else
          SyntaxTree::ERB::MAX_WIDTH
        end
      end

      def check_for_if_statement(node)
        return false if node.nil?

        if node.is_a?(SyntaxTree::IfNode) || node.is_a?(SyntaxTree::IfOp)
          return true
        end

        node.child_nodes.any? do |child_node|
          check_for_if_statement(child_node)
        end
      end
    end
  end
end
