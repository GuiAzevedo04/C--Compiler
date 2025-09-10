%option noyywrap

%{

/* −−−−−−−−−−−−−−−−−−−−−−−−−− D e f i n i t i o n s −−−−−−−−−−−−−−−−−−−−−−−−−− */
#include<stdio.h>

int linha = 1;
int coluna = 1;
%}

digito                  [0-9]
letra                   [a-zA-Z]
identificador           {letra}({letra}|{digito}|\_)*
expoente                \E(\+|\-)? 
numero_inteiro          \-?{digito}+({expoente}{digito}+)?

op_relacional           ">"|"<"|"<="|">="|"!="|"="
op_aritmetico           "+"|"-"|"*"|"/"|"**"
op_logico               "and"|"or"

palavras_reservadas     "if"|"else"|"while"|"print"|"read"|"true"|"false"
tipos                   "int"|"float"

comentario_simples      \/\/.*\n

delim                   [ \t]
ws                      {delim}+
linha                   \n
other                   .

%%

%{
/* −−−−−−−−−−−−−−−−−−−−−−−−−−−−− Rules −−−−−−−−−−−−−−−−−−−−−−−−−−−−−*/
%} 

{numero_inteiro}            { fprintf(yyout,"Linha %d, Coluna %d: %s (NUMERO)\n", linha, coluna, yytext); coluna += yyleng; }
{op_relacional}             { fprintf(yyout,"Linha %d, Coluna %d: %s (OPRELACIONAL)\n", linha, coluna, yytext); coluna += yyleng; }
{op_aritmetico}             { fprintf(yyout,"Linha %d, Coluna %d: %s (OPARITMETICO)\n", linha, coluna, yytext); coluna += yyleng; }
{op_logico}                 { fprintf(yyout,"Linha %d, Coluna %d: %s (OPLOGICO)\n", linha, coluna, yytext); coluna += yyleng; }
{palavras_reservadas}       { fprintf(yyout,"Linha %d, Coluna %d: %s (PALAVRASRESERVADAS)\n", linha, coluna, yytext); coluna += yyleng; }
{tipos}                     { fprintf(yyout,"Linha %d, Coluna %d: %s (TIPOS)\n", linha, coluna, yytext); coluna += yyleng; }
{identificador}             { fprintf(yyout,"Linha %d, Coluna %d: %s (ID)\n", linha, coluna, yytext); coluna += yyleng; }
{comentario_simples}        { fprintf(yyout,"Linha %d, Coluna %d: %s (COMENTARIO)\n", linha, coluna, yytext); coluna += yyleng; linha++; }
{ws}                        { coluna += yyleng; } 
{linha}                     { linha++; coluna = 1; } 
{other}                     { fprintf(yyout, "Lexical error at line %d, column %d. Input -> \"%s\"\n", linha, coluna, yytext); coluna += yyleng; }
                    

%%
/* −−−−−−−−−−−−−−−−−−−−−−−− User subrotines −−−−−−−−−−−−−−−−−−−−−−−−*/
int main(int argc, char *argv[]){
    yyin = fopen(argv[1], "r"); /*não sabe o que é , estude argumentos de linha de comando em C */
    yyout=stdout;
    yylex();
    fclose(yyin);
    return 0;
}
