#!/usr/bin/env -S gawk -f 
#
# The MIT License (Expat)
# 
# Copyright (c) Alex Bishop
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

# Instructions:
#
# This script should be applied to the file `rb_tree_tests.py` in the repo
#   https://github.com/stanislavkozlovski/Red-Black-Tree
# Note, although this script does most of the work in the translation, 
#  the resulting file will still require some minor editing and corrections

BEGIN {
  # values:
  #   0 -> not-processing function
  #   1 -> reading a test function body
  #   2 -> reading multistring in function
  status = 0 

  # if we have initialised the rb_tree variable
  #   0 -> no
  #   1 -> yes
  initialised_rbtree = 0

  # the following variable is used to hold the name of a variable
  tmp_node_name = ""

  # The following is an array of all the node variables
  split("", node_variables) 

  # The following variable is used to parse multline comments
  split("", multiline_comment) 

  # In the python code, some varables are redefined.
  # The way in which I have written my zig translation does not allow for
  # any variable to be redefined.
  # Thus, I will keep track of the variables and relabel them accordingly
  #  (i.e. you can simpluate a redefinition with a relabelling)
  split("", relabelled_variables) 

  # print out the header
  printf("const std = @import(\"std\");\n")
  printf("const Order = std.math.Order;\n")
  printf("const testing = std.testing;\n")
  printf("\n")
  printf("const rbtreelib = @import(\"rbtree\");\n")
  printf("\n")
  printf("pub const RBTree = rbtreelib.RBTree;\n")
  printf("pub const RBTreeUnmanaged = rbtreelib.RBTreeUnmanaged;\n")
  printf("pub const RBTreeImplementation = rbtreelib.RBTreeImplementation;\n")
  printf("\n")
  printf("fn checkTreeEqual(tree: anytype, expected_values: anytype) !void {\n")
  printf("    var current = tree.findMin();\n")
  printf("    var index: usize = 0;\n")
  printf("\n")
  printf("    while (current) |c| : ({\n")
  printf("        index += 1;\n")
  printf("        current = c.next();\n")
  printf("    }) {\n")
  printf("        try testing.expect(c.key == expected_values[index]);\n")
  printf("    }\n")
  printf("\n")
  printf("    try testing.expect(index == expected_values.len);\n")
  printf("}\n")
  printf("\n")

}

/def test_add_0_to_100_delete_100_to_0\(self\)/ { 
  if (status == 1) {
    # we were alreading in a function, let's close that off
    printf "}\n" 
  }
  exit
}

# matches lines of the form
#  """  some text  """
#     (-----------)
#     m[1]
#
match($0, /"""(.*)"""/, m) && (status == 1) {
  printf("    //%s\n", m[1])
  next
}

# matches the beginning of a multiline docstring
#  """ some test
#     (-----------)
#     m[1]
#
match($0, /"""(.*)/, m) && (status == 1) {
  multiline_comment[length(multiline_comment)] = $0
  status = 2
  next
}

# matches the end of a multiline docstring
#   some test    """
#   (-----------)
#   m[1]
#
match($0, /(.*)"""/, m) && (status == 2) {
  multiline_comment[length(multiline_comment)] = $0
  status = 1

  # we will add this comment to our output
   print(processMultiline(multiline_comment))

  # clear our the comment
  split("", multiline_comment)

  next
}

# matches the middle part of a multline comment
#
status == 2 {
  multiline_comment[length(multiline_comment)] = $0
  next
}

# matches lines of the form:
#
#       def test_recoloring_only(self):
#                (-------------)
#                m[1]
match($0, /^[[:space:]]*def test_([A-Za-z0-9_]*)\(/, m) {
  if (status == 1) {
    # we were alreading in a function, let's close that off
    printf "}\n" 
  }

  status = 1 
  initialised_rbtree = 0 
  split("", node_variables) 
  split("", multiline_comment) 
  split("", relabelled_variables) 

  printf("test \"%s\" {\n", m[1])
  printf("    const Tree = RBTreeUnmanaged(\n")
  printf("        i32,\n")
  printf("        void,\n")
  printf("        void,\n")
  printf("        rbtreelib.defaultOrder(i32),\n")
  printf("        .{},\n")
  printf("        .{},\n")
  printf("    );\n")
  printf("    const Node = Tree.Node;\n")
  printf("    var allocator = testing.allocator;\n")
  printf("\n")

  next 
}

# matches a blank line
#
/^[[:space:]]*$/ && (status == 1) {
  printf("\n")
  next
}

# matches lines of the form:
#
#     rb_tree = RedBlackTree()
#
#  and
#
#     tree = RedBlackTree()
#
/^[[:space:]]*(rb_)?tree\s*=\s*RedBlackTree()/ && (status == 1) {
  next 
}

# Matches lines of the form:
#
#     expected_values = [-20, -10, 2, 4, 6, 8, 10, 15, 20, 25]
#     values = list(tree)
#     self.assertEqual(values, expected_values)
#
match($0, /^[[:space:]]*expected_values\s*=\s*\[([^\]]*)\]/, m) && (status == 1) {
  printf("    try checkTreeEqual(rb_tree, [_]i32{ %s });\n", m[1])
  next
}
/^[[:space:]]*values\s*=\s*list\((rb_|)tree\)/ && (status == 1) { next }
/^[[:space:]]*self.assertEqual\(values, expected_values\)/ && (status == 1) { next }


# matches lines of the form:
#
#     self.assertEqual(node_2.color, BLACK)
#                      (----------)  (---)
#                      m[1]          m[2]
#
match($0, /^[[:space:]]*self.assertEqual\(([A-Za-z0-9_.]*), (RED|BLACK)\)/, m) && (status == 1) {
  printf("    try testing.expect(%s == .%s);\n", processExpressionToValue(relabelExpression(m[1])), tolower(m[2]))
  next
}

# matches lines of the form
#
#   rb_tree.add(2)
#   (-)         ^
#   m[1]        m[2]
#
match($0, /^[[:space:]]*(rb_|)tree\.add\(([^)]*)\)/, m) && (status == 1) {
  if (initialised_rbtree == 0) {
    printf("    var rb_tree = Tree.init();\n")
    printf("\n")
    initialised_rbtree = 1
  }

  tmp_node_name = generateNodeNameFromInt(m[2])

  if (node_variables[tmp_node_name] == 1) {
    printf("    const %s = (try rb_tree.insert(allocator, %s, void{}, .no_clobber)).node;\n", tmp_node_name "_v2", m[2])
    printf("    defer allocator.destroy(%s);\n", tmp_node_name "_v2")
  } else {
    printf("    const %s = (try rb_tree.insert(allocator, %s, void{}, .no_clobber)).node;\n", tmp_node_name, m[2])
    printf("    defer allocator.destroy(%s);\n", tmp_node_name)
  }
  node_variables[tmp_node_name] = 1 
  next
}

# matches lines of the form
#
#   rb_tree.remove(2)
#   (-)         ^
#   m[1]        m[2]
#
match($0, /^[[:space:]]*(rb_|)tree\.remove\(([0-9-]*)\)/, m) && (status == 1) {
  if (initialised_rbtree == 0) {
    printf("    var rb_tree = Tree.init();\n")
    printf("\n")
    initialised_rbtree = 1
  }

  printf("    // we remove a node without deallocating it\n")
  printf("    _ = Tree.implementation.removeNode(&rb_tree.root, void{}, rb_tree.find(%s).?);\n", m[2])
  next
}


# matches lines of the form
#
#   node_1 = rb_tree.root.left
#   (----)   (---------------)
#   m[1]     m[2]
#
match($0, /^[[:space:]]*([A-Za-z0-9_]*)\s*=\s*([A-Za-z0-9_.]*)[[:space:]]*(#.*)?$/, m) && (status == 1) {
  if (node_variables[m[1]] == 1) {
    printf "    const hopefully_%s = %s;\n", m[1], processExpressionToValue(relabelExpression(m[2])) 
    relabelled_variables[m[1]] = 1
  } else {
    printf "    const %s = %s;\n", relabelExpression(m[1]), processExpressionToValue(relabelExpression(m[2])) 
    node_variables[m[1]] = 1
  }

  next
}

# matches lines of the form
#
#       rb_tree.root = root
#   and
#       tree.root = root
#
match($0, /^[[:space:]]*(rb_|)tree\.root\s*=\s*root[[:space:]]*(#.*)?$/, m) && (status == 1) {
  printf("    var rb_tree: Tree = .{ .root = root, .size = %i, .cache = void{} };\n", length(node_variables))

  initialised_rbtree = 1
  next
}

# matches lines of the form
#
#       node_m10.right = node_7.left
#       (------------)   (---------)
#       m[1]             m[2]
#
match($0, /^[[:space:]]*([A-Za-z0-9_]*\.[A-Za-z0-9_.]*)\s*=\s*([A-Za-z0-9_.]*)[[:space:]]*(#.*)?$/, m) && (status == 1) {
  printf("    %s = %s;\n", processExpression(relabelExpression(m[1])), processExpression(relabelExpression(m[2])))
  next
}

# matches lines of the form
#
#     self.assertEqual(rb_tree.find_node(5), node_5)
#                      (-)               ^   (----)
#                      m[1]            m[2]  m[3]
#
match($0, /^[[:space:]]*self\.assertEqual\((rb_|)tree.find_node\(([^)]*)\), ([A-Za-z0-9_]*)\)/, m) && (status == 1) {
  printf("    try testing.expectEqual(rb_tree.find(%s), %s);\n", m[2], relabelExpression(m[3]))
  next
}

# matches lines of the form
#
#     self.assertIsNone(rb_tree.find_node(-1)) 
#                      (-)                |/
#                      m[1]              m[2]
#
match($0, /^[[:space:]]*self\.assertIsNone\((rb_|)tree.find_node\(([^)]*)\)\)/, m) && (status == 1) {
  printf("    try testing.expectEqual(rb_tree.find(%s), null);\n", m[2])
  next
}

# matches expressions of the form
#
#     self.assertEqual(node_20.parent, node_23)
#                      (------------)  (-----)
#
match($0, /^[[:space:]]*self\.assertEqual\(([^,]*),\s*([^)]*)\)/, m) && (status == 1) {
  printf("    try testing.expectEqual(%s, %s);\n", processExpression(relabelExpression(m[1])), processExpression(relabelExpression(m[2])))
  next
}

# matches expressions of the form
#
#    self.assertIsNone(node_5.parent) 
#                      (-----------)
#
match($0, /^[[:space:]]*self\.assertIsNone\(([^)]*)\)/, m) && (status == 1) {
  printf("    try testing.expect(%s == null);\n", processExpression(relabelExpression(m[1])))
  next
}

# matches lines of the form:
#
#     root = Node(value=10, color=BLACK, parent=None)
#     (--)        (----)\|        (---)         (--)
#     m[1]        m[2]   m[3]     m[4]          m[5]
match($0, /^[[:space:]]*([A-Za-z0-9_]*)\s*=\s*Node\((value=|)([0-9\-]*), color=([A-Z]*), parent=([A-Za-z0-9_.]*)\)/, m) && (status == 1) {
  printf("\n")
  printf("    const %s = try allocator.create(Node);\n", m[1])
  printf("    defer allocator.destroy(%s);\n",m[1])
  printf("    %s.* = Node.init(.{ .key = %s, .color = .%s, .parent = %s });\n\n", relabelExpression(m[1]), m[3], tolower(m[4]), normaliseRef(relabelExpression(m[5])))
  node_variables[m[1]] = 1
  next
}


# matches lines of the form:
#
#    node_8 = Node(value=8, color=RED, parent=node_6, left=NIL_LEAF, right=NIL_LEAF) 
#    (----)        (----)|        (-)         (--)         (------)        (------)
#    m[1]         m[2]   m[3]     m[4]        m[5]         m[6]            m[7]
match($0, /^[[:space:]]*([A-Za-z0-9_]*)\s*=\s*Node\((value=|)([0-9\-]*), color=([A-Z]*), parent=([A-Za-z0-9_.]*), left=([A-Za-z0-9_.]*), right=([A-Za-z0-9_.]*)\)/, m) && (status == 1) {
  printf("\n")
  printf("    const %s = try allocator.create(Node);\n", m[1])
  printf("    defer allocator.destroy(%s);\n",m[1])
  printf("    %s.* = Node.init(.{ .key = %s, .color = .%s, .parent = %s, .left = %s, .right = %s });\n\n",
         m[1], m[3], tolower(m[4]), normaliseRef(relabelExpression(m[5])), normaliseRef(relabelExpression(m[6])), normaliseRef(relabelExpression(m[7])))
  node_variables[m[1]] = 1
  next
}


/^[[:space:]]*# \*\*\*\*\*\*\*/ && (status == 1) {
  printf("}\n") 
  status = 0 
  next
}

# matches a single comment
#
match($0, /^[[:space:]]*#[[:space:]]*(\S.*|)$/, m) && (status == 1) {
  printf("    // %s\n", m[1])
  next
}

status == 0 { next }

##########################################################
# Give an error if we're not accounting for some line
##########################################################

{
  print("unrecognised line : " $0) > "/dev/stderr"
}

##########################################################
# Support functions
##########################################################

function str(i) {
  return sprintf("%i", i) 
}

function normaliseRef(r) {
  if (r == "None") {
    return "null" 
  } else if (r == "NIL_LEAF") {
    return "null"
  } else {
    return r 
  }
}

function generateNodeNameFromInt(n) {
  if (int(n) < 0) {
    return "node_m" str( 0 - int(n) ) 
  } else {
    return "node_" n 
  }
}

function processExpression(rhs) {
  result = rhs 

  result = normaliseRef(result)

  result = gensub(/^tree/, "rb_tree", "g", result) 

  result = gensub(/\.root\./, ".root.?.", "g", result) 
  result = gensub(/\.left\./, ".left.?.", "g", result) 
  result = gensub(/\.right\./, ".right.?.", "g", result) 
  result = gensub(/\.parent\./, ".getParent().?.", "g", result) 

  result = gensub(/\.color/, ".getColor()", "g", result) 
  result = gensub(/\.parent/, ".getParent()", "g", result) 

  result = gensub(/\.value$/, ".key", "g", result) 

  return result 
}

function processExpressionToValue(rhs) {
  result = rhs 

  result = normaliseRef(result)

  result = gensub(/^tree/, "rb_tree", "g", result) 

  result = gensub(/\.root/, ".root.?", "g", result) 
  result = gensub(/\.left/, ".left.?", "g", result) 
  result = gensub(/\.right/, ".right.?", "g", result) 

  result = gensub(/\.color/, ".getColor()", "g", result) 
  result = gensub(/\.parent/, ".getParent().?", "g", result) 

  result = gensub(/\.value$/, ".key", "g", result) 

  return result 
}

function processMultiline(comment) {
  prefix_len = -1
  
  split("", tmp_arr)
  for (i in comment) {
    line = gensub(/"""/,"   ", "g", comment[i])
    tmp_arr[length(tmp_arr)] = line

    if (match(line, /^([[:space:]]*)\S/, m)) {
      if (prefix_len < 0 || length(m[1]) < prefix_len) {
        prefix_len = length(m[1])
      }
    }
  }

  if (prefix_len < 0) {
    prefix_len = 0
  }

  result = ""
  for (i in tmp_arr) {
    line = tmp_arr[i]
    if (length(line) >= prefix_len) {
      line = substr(line, prefix_len + 1)
    } else {
      line = ""
    }
    result = result "\n    // " line
  }
  result = substr(result, 1)

  return result
}

function relabelExpression(expression) {
  for (v in relabelled_variables) {
    if (expression == v) {
      return "hopefully_" expression
    }
    if (expression ~ "^" v "\\.") {
      return "hopefully_" expression
    }
  }
  return expression
}

