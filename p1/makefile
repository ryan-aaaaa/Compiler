all: b11115030.out

b11115030.out: lex.yy.c
	g++ lex.yy.c -o b11115030.out -ll

lex.yy.c: b11115030.l
	flex b11115030.l

clean:
	rm -f b11115030.out lex.yy.c

