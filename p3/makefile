.PHONY: all clean

all: parser

parser: lex.yy.cpp y.tab.cpp SymbolTable.cpp AST.cpp CodeGenerator.cpp
	g++ y.tab.cpp SymbolTable.cpp AST.cpp CodeGenerator.cpp -o parser -ll 

lex.yy.cpp: scanner.l
	flex -o lex.yy.cpp scanner.l

y.tab.cpp y.tab.hpp: parser.y SymbolTable.hpp AST.hpp CodeGenerator.hpp
	yacc -d -y -o y.tab.cpp parser.y

run: 
	./parser test/test2.sd
	./../javaa/javaa test2.jasm
	./../jre1.8.0_451/bin/java test2

clean:
	rm -f parser lex.yy.cpp y.tab.cpp y.tab.hpp *.out *.jasm *.class
