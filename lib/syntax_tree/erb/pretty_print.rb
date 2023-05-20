# frozen_string_literal: true

module SyntaxTree
  module ERB
    class PrettyPrint < Visitor
      attr_reader :q

      def initialize(q)
        @q = q
      end

      # Visit a Token node.
      def visit_token(node)
        q.pp(node.value)
      end

      # Visit a Document node.
      def visit_document(node)
        visit_node("document", node)
      end

      # Visit an HtmlNode.
      def visit_html(node)
        visit_node("html", node)
      end

      # Visit an HtmlNode::OpeningTag node.
      def visit_opening_tag(node)
        visit_node("opening_tag", node)
      end

      # Visit an HtmlNode::ClosingTag node.
      def visit_closing_tag(node)
        visit_node("closing_tag", node)
      end

      # Visit an ErbNode node.
      def visit_erb(node)
        q.group do
          q.text("(erb")
          q.nest(2) do
            q.breakable
            visit(node.opening_tag)
            if node.keyword
              q.breakable
              visit(node.keyword)
            end
            if node.content
              q.breakable
              q.text("content")
            end

            q.breakable
            visit(node.closing_tag)
          end
          q.breakable("")
          q.text(")")
        end
      end

      def visit_erb_block(node)
        q.group do
          q.text("(erb_block")
          q.nest(2) do
            q.breakable
            q.seplist(node.child_nodes) { |child_node| visit(child_node) }
          end
          q.breakable
          visit(node.consequent)
          q.breakable("")
          q.text(")")
        end
      end

      def visit_erb_if(node, key = "erb_if")
        q.group do
          q.text("(")
          visit(node.keyword) if node.keyword
          q.nest(2) do
            q.breakable()
            q.seplist(node.child_nodes) { |child_node| visit(child_node) }
          end
          q.breakable
          visit(node.consequent)
          q.breakable("")
          q.text(")")
        end
      end

      def visit_erb_end(node)
        q.text("erb_end")
      end

      # Visit an ErbContent node.
      def visit_erb_content(node)
        q.text(node.value)
      end

      # Visit a Reference node.
      def visit_reference(node)
        visit_node("reference", node)
      end

      # Visit an Attribute node.
      def visit_attribute(node)
        visit_node("attribute", node)
      end

      # Visit an ErbString node.
      def visit_erb_string(node)
        visit_node("erb_string", node)
      end

      # Visit a CharData node.
      def visit_char_data(node)
        visit_node("char_data", node)
      end

      def visit_erb_do_close(node)
        visit_node("erb_do_close", node)
      end

      # Visit a Doctype node.
      def visit_doctype(node)
        visit_node("doctype", node)
      end

      private

      # A generic visit node function for how we pretty print nodes.
      def visit_node(type, node)
        q.group do
          q.text("(#{type}")
          q.nest(2) do
            q.breakable
            q.seplist(node.child_nodes) { |child_node| visit(child_node) }
          end
          q.breakable("")
          q.text(")")
        end
      end

      def comments(node)
        return if node.comments.empty?

        q.breakable
        q.group(2, "(", ")") do
          q.seplist(node.comments) { |comment| q.pp(comment) }
        end
      end

      def field(_name, value)
        q.breakable
        q.pp(value)
      end

      def list(_name, values)
        q.breakable
        q.group(2, "(", ")") { q.seplist(values) { |value| q.pp(value) } }
      end

      def node(_node, type)
        q.group(2, "(", ")") do
          q.text(type)
          yield
        end
      end

      def pairs(_name, values)
        q.group(2, "(", ")") do
          q.seplist(values) do |(key, value)|
            q.pp(key)

            if value
              q.text("=")
              q.group(2) do
                q.breakable("")
                q.pp(value)
              end
            end
          end
        end
      end

      def text(_name, value)
        q.breakable
        q.text(value)
      end
    end
  end
end
