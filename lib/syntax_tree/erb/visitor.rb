# frozen_string_literal: true

module SyntaxTree
  module ERB
    # Provides a visitor interface for visiting certain nodes. It's used
    # internally to implement formatting and pretty-printing. It could also be
    # used externally to visit a subset of nodes that are relevant to a certain
    # task.
    class Visitor < SyntaxTree::Visitor
      def visit(node)
        node&.accept(self)
      end

      alias visit_statements visit_child_nodes

      private

      def visit_all(nodes)
        nodes.map { |node| visit(node) }
      end

      def visit_child_nodes(node)
        visit_all(node.child_nodes)
      end

      # Visit a Token node.
      alias visit_token visit_child_nodes

      # Visit a Document node.
      alias visit_document visit_child_nodes

      # Visit an Html node.
      alias visit_html visit_child_nodes

      # Visit an HtmlNode::OpeningTag node.
      alias visit_opening_tag visit_child_nodes

      # Visit an HtmlNode::ClosingTag node.
      alias visit_closing_tag visit_child_nodes

      # Visit a Reference node.
      alias visit_reference visit_child_nodes

      # Visit an Attribute node.
      alias visit_attribute visit_child_nodes

      # Visit a CharData node.
      alias visit_char_data visit_child_nodes

      # Visit an ErbNode node.
      alias visit_erb visit_child_nodes

      # Visit a HtmlString node.
      alias visit_html_string visit_child_nodes
    end
  end
end
