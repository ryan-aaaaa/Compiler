# .PHONY: all clean

# all: parser

# # generate parser
# # symbols.cpp, symbols.hpp defines symbol table
# # parser: lex.yy.cpp y.tab.cpp symbols.cpp
# # 	g++ y.tab.cpp lex.yy.cpp -o parser -ll

# parser: lex.yy.cpp y.tab.cpp
# 	g++ y.tab.cpp -o parser -ll

# # generate lex.yy.cpp (lex.yy.c)
# lex.yy.cpp: scanner.l
# 	flex -o lex.yy.cpp scanner.l

# # generate y.tab.hpp and y.tab.cpp (y.tab.h and y.tab.c)
# y.tab.cpp: parser.y
# 	yacc -y -d parser.y -o y.tab.cpp

# clean:
# 	rm -f parser lex.yy.* y.tab.* *.out


.PHONY: all clean

all: parser

parser: lex.yy.cpp y.tab.cpp SymbolTable.cpp AST.cpp
	g++ y.tab.cpp SymbolTable.cpp AST.cpp -o parser -ll

lex.yy.cpp: scanner.l
	flex -o lex.yy.cpp scanner.l

y.tab.cpp y.tab.hpp: parser.y SymbolTable.hpp
	yacc -d -y -o y.tab.cpp parser.y

clean:
	rm -f parser lex.yy.cpp y.tab.cpp y.tab.hpp *.out
