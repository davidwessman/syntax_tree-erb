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

      def visit_html(node)
        q.group do
          visit(node.opening_tag)

          if node.content&.any?
            q.indent do
              q.breakable("")
              q.seplist(
                node.content,
                -> { q.breakable(force: true) }
              ) { |child_node| visit(child_node) }
            end
          end

          q.breakable("")
          visit(node.closing_tag)
        end
      end

      # Visit an ErbNode node.
      def visit_erb(node)
        visit(node.opening_tag)

        q.text(" ")
        visit(node.content)
        q.text(" ")

        visit(node.closing_tag)
      end

      def visit_erb_block(node)
        visit(node.erb_node)

        if node.elements.any?
          q.group do
            q.indent do
              q.breakable(force: true)
              q.seplist(
                node.elements,
                -> { q.breakable(force: true) }
              ) { |child_node| visit(child_node) }
            end
          end
        end

        q.breakable("")
        visit(node.consequent)
      end

      def visit_erb_do_close(node)
        q.text(node.value.rstrip)
        q.text(" %>")
      end

      # Visit an ErbIf node.
      def visit_erb_if(node, key: "if")
        q.group do
          q.text("<% #{key} ")
          visit(node.erb_node.content)
          q.text(" %>")

          if node.elements.any?
            q.indent do
              q.breakable(force: true)
              q.seplist(
                node.elements,
                -> { q.breakable(force: true) }
              ) { |child_node| visit(child_node) }
            end
          end

          q.breakable("")
          visit(node.consequent)
        end
      end

      # Visit an ErbUnless node.
      def visit_erb_unless(node)
        visit_erb_if(node, key: "unless")
      end

      # Visit an ErbElsIf node.
      def visit_erb_elsif(node)
        visit_erb_if(node, key: "elsif")
      end

      # Visit an ErbElse node.
      def visit_erb_else(node)
        q.group do
          q.text("<% else %>")

          q.indent do
            q.breakable
            visit_all(node.elements)
          end

          q.breakable_force
          visit(node.consequent)
        end
      end

      # Visit an ErbEnd node.
      def visit_erb_end(node)
        q.text("<% end %>")
      end

      def visit_erb_content(node)
        if (node.value.is_a?(String))
          q.text(node.value)
        else
          formatter =
            SyntaxTree::Formatter.new("", [], SyntaxTree::ERB::MAX_WIDTH)
          formatter.format(node.value.statements)
          formatter.flush

          rows = formatter.output.join.split("\n")

          if rows.size > 1
            q.group do
              q.seplist(rows, -> { q.breakable(" ") }) { |row| q.text(row) }
            end
          else
            q.text(rows.first)
          end
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

      # Visit a Reference node.
      def visit_reference(node)
        visit(node.value)
      end

      # Visit an Attribute node.
      def visit_attribute(node)
        q.group do
          visit(node.key)
          visit(node.equals)
          visit(node.value)
        end
      end

      # Visit an ErbString node.
      def visit_erb_string(node)
        q.group do
          visit(node.opening)
          q.seplist(node.contents, -> { "" }) { |child_node| visit(child_node) }
          visit(node.closing)
        end
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

      private

      # Format a text by splitting nicely at newlines and spaces.
      def format_text(q, value)
        sep_line = -> { q.breakable(force: true, indent: false) }
        sep_word = -> { q.group { q.breakable } }

        q.seplist(value.strip.split("\n"), sep_line) do |line|
          q.seplist(line.split(/\b(?: +)\b/), sep_word) { |word| q.text(word) }
        end
      end
    end
  end
end
