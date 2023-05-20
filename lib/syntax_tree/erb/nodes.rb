# frozen_string_literal: true

module SyntaxTree
  module ERB
    # A Location represents a position for a node in the source file.
    class Location
      attr_reader :start_char, :end_char, :start_line, :end_line

      def initialize(start_char:, end_char:, start_line:, end_line:)
        @start_char = start_char
        @end_char = end_char
        @start_line = start_line
        @end_line = end_line
      end

      def deconstruct_keys(keys)
        {
          start_char: start_char,
          end_char: end_char,
          start_line: start_line,
          end_line: end_line
        }
      end

      def to(other)
        Location.new(
          start_char: start_char,
          start_line: start_line,
          end_char: other.end_char,
          end_line: other.end_line
        )
      end

      def <=>(other)
        start_char <=> other.start_char
      end
    end

    # A parent node that contains a bit of shared functionality.
    class Node
      def format(q)
        Format.new(q).visit(self)
      end

      def pretty_print(q)
        PrettyPrint.new(q).visit(self)
      end
    end

    # A Token is any kind of lexical token from the source. It has a type, a
    # value which is a subset of the source, and an index where it starts in
    # the source.
    class Token < Node
      attr_reader :type, :value, :location

      def initialize(type:, value:, location:)
        @type = type
        @value = value
        @location = location
      end

      def accept(visitor)
        visitor.visit_token(self)
      end

      def child_nodes
        []
      end

      alias deconstruct child_nodes

      def deconstruct_keys(keys)
        { type: type, value: value, location: location }
      end
    end

    # The Document node is the top of the syntax tree.
    # It contains any number of:
    # - Text
    # - HtmlNode
    # - ErbNodes
    class Document < Node
      attr_reader :elements, :location

      def initialize(elements:, location:)
        @elements = elements
        @location = location
      end

      def accept(visitor)
        visitor.visit_document(self)
      end

      def child_nodes
        [*elements].compact
      end

      alias deconstruct child_nodes

      def deconstruct_keys(keys)
        { elements: elements, location: location }
      end
    end

    # An element is a child of the document. It contains an opening tag, any
    # optional content within the tag, and a closing tag. It can also
    # potentially contain an opening tag that self-closes, in which case the
    # content and closing tag will be nil.
    class HtmlNode < Node
      # The opening tag of an element. It contains the opening character (<),
      # the name of the element, any optional attributes, and the closing
      # token (either > or />).
      class OpeningTag < Node
        attr_reader :opening, :name, :attributes, :closing, :location

        def initialize(opening:, name:, attributes:, closing:, location:)
          @opening = opening
          @name = name
          @attributes = attributes
          @closing = closing
          @location = location
        end

        def accept(visitor)
          visitor.visit_opening_tag(self)
        end

        def child_nodes
          [opening, name, *attributes, closing]
        end

        alias deconstruct child_nodes

        def deconstruct_keys(keys)
          {
            opening: opening,
            name: name,
            attributes: attributes,
            closing: closing,
            location: location
          }
        end
      end

      # The closing tag of an element. It contains the opening character (<),
      # the name of the element, and the closing character (>).
      class ClosingTag < Node
        attr_reader :opening, :name, :closing, :location

        def initialize(opening:, name:, closing:, location:)
          @opening = opening
          @name = name
          @closing = closing
          @location = location
        end

        def accept(visitor)
          visitor.visit_closing_tag(self)
        end

        def child_nodes
          [opening, name, closing]
        end

        alias deconstruct child_nodes

        def deconstruct_keys(keys)
          { opening: opening, name: name, closing: closing, location: location }
        end
      end

      attr_reader :opening_tag, :content, :closing_tag, :location

      def initialize(opening_tag:, content:, closing_tag:, location:)
        @opening_tag = opening_tag
        @content = content
        @closing_tag = closing_tag
        @location = location
      end

      def accept(visitor)
        visitor.visit_html(self)
      end

      def child_nodes
        [opening_tag, *content, closing_tag].compact
      end

      alias deconstruct child_nodes

      def deconstruct_keys(keys)
        {
          opening_tag: opening_tag,
          content: content,
          closing_tag: closing_tag,
          location: location
        }
      end
    end

    class ErbNode < Node
      attr_reader :opening_tag, :keyword, :content, :closing_tag, :location

      def initialize(opening_tag:, keyword:, content:, closing_tag:, location:)
        @opening_tag = opening_tag
        @keyword = keyword
        @content = ErbContent.new(value: content) if content
        @closing_tag = closing_tag
        @location = location
      end

      def accept(visitor)
        visitor.visit_erb(self)
      end

      def child_nodes
        [opening_tag, keyword, content, closing_tag].compact
      end

      alias deconstruct child_nodes

      def deconstruct_keys(keys)
        {
          opening_tag: opening_tag,
          keyword: keyword,
          content: content,
          closing_tag: closing_tag,
          location: location
        }
      end
    end

    class ErbBlock < Node
      attr_reader :erb_node, :elements, :consequent, :location

      def initialize(erb_node:, elements:, consequent:)
        @erb_node = erb_node
        @elements = elements
        @consequent = consequent
        @location = erb_node.location.to(consequent.location)
      end

      def accept(visitor)
        visitor.visit_erb_block(self)
      end

      def child_nodes
        [*elements].compact
      end

      alias deconstruct child_nodes

      def deconstruct_keys(keys)
        {
          erb_node: erb_node,
          elements: elements,
          consequent: consequent,
          location: location
        }
      end
    end

    class ErbDoClose < Node
      attr_reader :location, :value, :closing

      def initialize(location:, value:, closing:)
        @location = location
        @value = value
        @closing = closing
      end

      def accept(visitor)
        visitor.visit_erb_do_close(self)
      end

      def child_nodes
        []
      end

      alias deconstruct child_nodes

      def deconstruct_keys(keys)
        { location: location, value: value, closing: closing }
      end
    end

    class ErbControl < Node
      attr_reader :erb_node

      def initialize(erb_node:)
        @erb_node = erb_node
      end

      def location
        erb_node.location
      end
    end

    class ErbIf < ErbControl
      attr_reader :erb_node

      # [[HtmlNode | ErbNode | CharDataNode]] the child elements
      attr_reader :elements

      # [nil | ErbElsif | ErbElse] the next clause in the chain
      attr_reader :consequent

      def initialize(erb_node:, elements:, consequent:)
        super(erb_node: erb_node)
        @elements = elements
        @consequent = consequent
      end

      def accept(visitor)
        visitor.visit_erb_if(self)
      end

      def child_nodes
        elements
      end

      alias deconstruct child_nodes

      def deconstruct_keys(keys)
        {
          erb_node: erb_node,
          elements: elements,
          consequent: consequent,
          location: location
        }
      end
    end

    class ErbUnless < ErbIf
    end

    class ErbElsif < ErbIf
    end

    class ErbElse < ErbIf
    end

    class ErbEnd < ErbNode
      def accept(visitor)
        visitor.visit_erb_end(self)
      end

      def child_nodes
        []
      end

      alias deconstruct child_nodes
    end

    class ErbContent < Node
      attr_reader(:value, :parsed)

      def initialize(value:)
        @value = value
        begin
          @value = SyntaxTree.parse(@value)
          @parsed = true
        rescue SyntaxTree::Parser::ParseError
          # Removes leading and trailing whitespace
          @value = @value&.lstrip&.rstrip
          @parsed = false
        end
      end

      def accept(visitor)
        visitor.visit_erb_content(self)
      end

      def child_nodes
        []
      end

      alias deconstruct child_nodes

      def deconstruct_keys(keys)
        { value: value }
      end
    end

    # An HtmlAttribute is a key-value pair within a tag. It contains the key, the
    # equals sign, and the value.
    class HtmlAttribute < Node
      attr_reader :key, :equals, :value, :location

      def initialize(key:, equals:, value:, location:)
        @key = key
        @equals = equals
        @value = value
        @location = location
      end

      def accept(visitor)
        visitor.visit_attribute(self)
      end

      def child_nodes
        [key, equals, value]
      end

      alias deconstruct child_nodes

      def deconstruct_keys(keys)
        { key: key, equals: equals, value: value, location: location }
      end
    end

    # An ErbString can include ERB-tags
    class ErbString < Node
      attr_reader :opening, :contents, :closing, :location

      def initialize(opening:, contents:, closing:, location:)
        @opening = opening
        @contents = contents
        @closing = closing
        @location = location
      end

      def accept(visitor)
        visitor.visit_erb_string(self)
      end

      def child_nodes
        [*contents]
      end

      alias deconstruct child_nodes

      def deconstruct_keys(keys)
        {
          opening: opening,
          contents: contents,
          closing: closing,
          location: location
        }
      end
    end

    # A CharData contains either plain text or whitespace within an element.
    # It wraps a single token value.
    class CharData < Node
      attr_reader :value, :location

      def initialize(value:, location:)
        @value = value
        @location = location
      end

      def accept(visitor)
        visitor.visit_char_data(self)
      end

      def child_nodes
        [value]
      end

      alias deconstruct child_nodes

      def deconstruct_keys(keys)
        { value: value, location: location }
      end
    end

    # A document type declaration is a special kind of tag that specifies the
    # type of the document. It contains an opening declaration, the name of
    # the document type, an optional external identifier, and a closing of the
    # tag.
    class DocType < Node
      attr_reader :opening, :name, :closing, :location

      def initialize(opening:, name:, closing:, location:)
        @opening = opening
        @name = name
        @closing = closing
        @location = location
      end

      def accept(visitor)
        visitor.visit_doctype(self)
      end

      def child_nodes
        [opening, name, closing].compact
      end

      alias deconstruct child_nodes

      def deconstruct_keys(keys)
        { opening: opening, name: name, closing: closing, location: location }
      end
    end
  end
end
