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
        if %i[text whitespace].include?(node.type)
          q.text(node.value)
        else
          q.text(node.value.strip)
        end
      end

      # Visit a Document node.
      def visit_document(node)
        child_nodes = node.child_nodes.sort_by(&:location)

        handle_child_nodes(child_nodes)

        q.breakable(force: true)
      end

      def visit_block(node)
        visit(node.opening)

        breakable = breakable_inside(node)
        if node.elements.any?
          q.indent do
            q.breakable if breakable
            handle_child_nodes(node.elements)
          end
        end

        if node.closing
          q.breakable("") if breakable
          visit(node.closing)
        end
      end

      def visit_html_groupable(node, group)
        if node.elements.size == 0
          visit(node.opening)
          visit(node.closing)
        else
          visit(node.opening)

          with_break = breakable_inside(node)
          q.indent do
            if with_break
              group ? q.breakable("") : q.breakable
            end
            handle_child_nodes(node.elements)
          end

          if with_break
            group ? q.breakable("") : q.breakable
          end
          visit(node.closing)
        end
      end

      def visit_html(node)
        # Make sure to group the tags together if there is no child nodes.
        if node.elements.size == 0 ||
             node.elements.any? { |node|
               node.is_a?(SyntaxTree::ERB::CharData)
             } ||
             (
               node.elements.size == 1 &&
                 node.elements.first.is_a?(SyntaxTree::ERB::ErbNode)
             )
          q.group { visit_html_groupable(node, true) }
        else
          visit_html_groupable(node, false)
        end
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
        node.content.blank? ? q.text(" ") : visit(node.content)

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
        nodes = node.value&.statements&.child_nodes || []

        if nodes.size == 1
          q.text(" ")
          q.seplist(nodes, -> { q.breakable("") }) do |child_node|
            format_statement(child_node)
          end
          q.text(" ")
        elsif nodes.size > 1
          q.indent do
            q.breakable("")
            q.seplist(nodes, -> { q.breakable("") }) do |child_node|
              format_statement(child_node)
            end
          end

          q.breakable
        end
      end

      def format_statement(statement)
        formatter =
          SyntaxTree::Formatter.new("", [], SyntaxTree::ERB::MAX_WIDTH)

        formatter.format(statement)
        formatter.flush
        rows = formatter.output.join.split("\n")

        output_rows(rows)
      end

      def output_rows(rows)
        if rows.size > 1
          q.seplist(rows, -> { q.breakable("") }) { |row| q.text(row) }
        elsif rows.size == 1
          q.text(rows.first)
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

            # Only add breakable if we have attributes
            q.breakable(node.closing.value == "/>" ? " " : "")
          elsif node.closing.value == "/>"
            # Need a space before end-tag for self-closing
            q.text(" ")
          end

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

      def visit_erb_comment(node)
        visit(node.token)
      end

      # Visit a CharData node.
      def visit_char_data(node)
        return if node.value.value.strip.empty?

        q.text(node.value.value)
      end

      def visit_new_line(node)
        q.breakable(force: :skip_parent_break)
        q.breakable(force: :skip_parent_break) if node.count > 1
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

      private

      def breakable_inside(node)
        if node.is_a?(SyntaxTree::ERB::HtmlNode)
          node.elements.first.class != SyntaxTree::ERB::CharData ||
            node_new_line_count(node.opening) > 0
        elsif node.is_a?(SyntaxTree::ERB::Block)
          true
        end
      end

      def breakable_between(node, next_node)
        new_lines = node_new_line_count(node)

        if new_lines == 1
          q.breakable
        elsif new_lines > 1
          q.breakable
          q.breakable(force: :skip_parent_break)
        elsif next_node && !node.is_a?(SyntaxTree::ERB::CharData) &&
              !next_node.is_a?(SyntaxTree::ERB::CharData)
          q.breakable
        end
      end

      def breakable_between_group(node, next_node)
        new_lines = node_new_line_count(node)

        if new_lines == 1
          q.breakable(force: true)
        elsif new_lines > 1
          q.breakable(force: true)
          q.breakable(force: true)
        elsif next_node && !node.is_a?(SyntaxTree::ERB::CharData) &&
              !next_node.is_a?(SyntaxTree::ERB::CharData)
          q.breakable("")
        end
      end

      def node_new_line_count(node)
        node.respond_to?(:new_line) ? node.new_line&.count || 0 : 0
      end

      def handle_child_nodes(child_nodes)
        group = []

        if child_nodes.size == 1
          visit(child_nodes.first.without_new_line)
          return
        end

        child_nodes.each_with_index do |child_node, index|
          is_last = index == child_nodes.size - 1

          # Last element should not have new lines
          node = is_last ? child_node.without_new_line : child_node

          if node_should_group(node)
            group << node
            next
          end

          # Render all group elements before the current node
          handle_group(group, break_after: true)
          group = []

          # Render the current node
          visit(node)
          next_node = child_nodes[index + 1]

          breakable_between(node, next_node)
        end

        # Handle group if we have any nodes left
        handle_group(group, break_after: false)
      end

      def handle_group(nodes, break_after:)
        if nodes.size == 1
          handle_group_nodes(nodes)
        elsif nodes.size > 1
          q.group { handle_group_nodes(nodes) }
        else
          return
        end

        breakable_between_group(nodes.last, nil) if break_after
      end

      def handle_group_nodes(nodes)
        nodes.each_with_index do |node, group_index|
          visit(node)
          next_node = nodes[group_index + 1]
          next if next_node.nil?
          breakable_between_group(node, next_node)
        end
      end

      def node_should_group(node)
        node.is_a?(SyntaxTree::ERB::CharData) ||
          node.is_a?(SyntaxTree::ERB::ErbNode)
      end
    end
  end
end
