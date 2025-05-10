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
