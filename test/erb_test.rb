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

    def test_erb_code_with_non_ascii
      parsed = ERB.parse("<% \"Påäööööö\" %>")
      assert_equal(1, parsed.elements.size)
      assert_instance_of(SyntaxTree::ERB::ErbNode, parsed.elements.first)
    end
  end
end
