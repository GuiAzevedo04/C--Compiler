bison -d parser.y
flex main.l
gcc -o a parser.tab.c lex.yy.c -lfl
./a teste.txt
