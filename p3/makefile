.PHONY: all clean

all: parser

parser: lex.yy.cpp y.tab.cpp SymbolTable.cpp AST.cpp CodeGenerator.cpp
	g++ y.tab.cpp SymbolTable.cpp AST.cpp CodeGenerator.cpp -o parser -ll 

lex.yy.cpp: scanner.l
	flex -o lex.yy.cpp scanner.l

y.tab.cpp y.tab.hpp: parser.y SymbolTable.hpp AST.hpp CodeGenerator.hpp
	yacc -d -y -o y.tab.cpp parser.y

basic_test: parser
	./parser test/basic.sd

extra_test: parser
	./parser test/extra.sd

example: parser
	./parser test/example.sd

run: 
	./../javaa/javaa example.jasm
	./../jre1.8.0_451/bin/java example

clean:
	rm -f parser lex.yy.cpp y.tab.cpp y.tab.hpp *.out *.jasm *.class
