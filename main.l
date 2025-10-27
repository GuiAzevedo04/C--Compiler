%option noyywrap
%option yylineno

%{

/* −−−−−−−−−−−−−−−−−−−−−−−−−− D e f i n i t i o n s −−−−−−−−−−−−−−−−−−−−−−−−−− */
#include<stdio.h>
#include <string.h>
#include <stdlib.h>
#include "parser.tab.h"

int linha = 1;
int coluna = 1;

#define HASH_SIZE 211  // número primo para diminuir colisões

typedef struct Simbolo {
    char *lexema;
    struct Simbolo *prox;  // lista encadeada em caso de colisão
} Simbolo;

Simbolo *tabela[HASH_SIZE];  // vetor de listas

unsigned int hash(char *lexema) {
    unsigned int h = 0;
    for (int i = 0; lexema[i] != '\0'; i++) {
        h = h * 37 + lexema[i];  // multiplica por um número primo e soma o caractere
    }
    return h % HASH_SIZE;        // garante que caia dentro da tabela
}

void inserir_simbolo(char *lexema) {
    unsigned int idx = hash(lexema);
    Simbolo *atual = tabela[idx];

    // verifica se já existe
    while (atual != NULL) {
        if (strcmp(atual->lexema, lexema) == 0) {
            return; // já existe, não insere
        }
        atual = atual->prox;
    }

    // cria novo símbolo
    Simbolo *novo = (Simbolo *) malloc(sizeof(Simbolo));
    novo->lexema = strdup(lexema);
    novo->prox = tabela[idx];
    tabela[idx] = novo;
}

void imprimir_tabela() {
    printf("\n=== TABELA DE SIMBOLOS ===\n");
    for (int i = 0; i < HASH_SIZE; i++) {
        Simbolo *atual = tabela[i];
        while (atual != NULL) {
            printf("%s\n", atual->lexema);
            atual = atual->prox;
        }
    }
}

%}

digito                  [0-9]
digito_nao_zero         [1-9]
letra                   [a-zA-Z]
identificador           {letra}({letra}|{digito}|\_)*
numero_inteiro          (0|-?{digito_nao_zero}{digito}*)

string                  \"([^\\\"]|\\.)*\"

op_relacional           "=="|"!="|"<"|"<="|">"|">="
atribuicao              "="
op_aritmetico           "+"|"-"|"*"|"/"|"%"
op_logico_and           "&&"
op_logico_or            "||"
op_logico_not           "!"

tipos                   "int"|"bool"

ponto_virgula           ";"
virgula                 ","
parenteses_abre         "("
parenteses_fecha        ")"
chave_abre              "{"
chave_fecha             "}"

comentario_simples      "//".*
comentario_mult         "/*"([^*]|\*+[^*/])*\*+"/"

delim                   [ \t]
ws                      {delim}+
linha                   \r?\n
other                   .

%%

%{
/* −−−−−−−−−−−−−−−−−−−−−−−−−−−−− Rules −−−−−−−−−−−−−−−−−−−−−−−−−−−−−*/
%} 

"if"                        { fprintf(yyout,"Linha %d, Coluna %d: %s (IF)\n", yylineno, coluna, yytext); coluna += yyleng; return IF; }
"else"                      { fprintf(yyout,"Linha %d, Coluna %d: %s (ELSE)\n", yylineno, coluna, yytext); coluna += yyleng; return ELSE; }
"while"                     { fprintf(yyout,"Linha %d, Coluna %d: %s (WHILE)\n", yylineno, coluna, yytext); coluna += yyleng; return WHILE; }
"print"                     { fprintf(yyout,"Linha %d, Coluna %d: %s (PRINT)\n", yylineno, coluna, yytext); coluna += yyleng; return PRINT; }
"read"                      { fprintf(yyout,"Linha %d, Coluna %d: %s (READ)\n", yylineno, coluna, yytext); coluna += yyleng; return READ; }

{numero_inteiro}            { fprintf(yyout,"Linha %d, Coluna %d: %s (NUMERO)\n", linha, coluna, yytext); coluna += yyleng; return NUMERO; }
{string}                    { fprintf(yyout,"Linha %d, Coluna %d: %s (STRING)\n", yylineno, coluna, yytext); coluna += yyleng; return STRING; }
{op_relacional}             { fprintf(yyout,"Linha %d, Coluna %d: %s (OPRELACIONAL)\n", linha, coluna, yytext); coluna += yyleng; return OPRELACIONAL;}

{atribuicao}                { fprintf(yyout,"Linha %d, Coluna %d: %s (ATRIBUICAO)\n", linha, coluna, yytext); coluna += yyleng; return ATRIBUICAO;}

"+"                         { fprintf(yyout,"Linha %d, Coluna %d: %s (MAIS)\n", yylineno, coluna, yytext); coluna += yyleng; return '+'; }
"-"                         { fprintf(yyout,"Linha %d, Coluna %d: %s (MENOS)\n", yylineno, coluna, yytext); coluna += yyleng; return '-'; }
"*"                         { fprintf(yyout,"Linha %d, Coluna %d: %s (MULT)\n", yylineno, coluna, yytext); coluna += yyleng; return '*'; }
"/"                         { fprintf(yyout,"Linha %d, Coluna %d: %s (DIV)\n", yylineno, coluna, yytext); coluna += yyleng; return '/'; }
"%"                         { fprintf(yyout,"Linha %d, Coluna %d: %s (MOD)\n", yylineno, coluna, yytext); coluna += yyleng; return '%'; }


{op_logico_and}             { fprintf(yyout,"Linha %d, Coluna %d: %s (OPLOGICO_AND)\n", yylineno, coluna, yytext); coluna += yyleng; return OPLOGICO_AND; }
{op_logico_or}              { fprintf(yyout,"Linha %d, Coluna %d: %s (OPLOGICO_OR)\n", yylineno, coluna, yytext); coluna += yyleng; return OPLOGICO_OR; }
{op_logico_not}             { fprintf(yyout,"Linha %d, Coluna %d: %s (OPLOGICO_NOT)\n", yylineno, coluna, yytext); coluna += yyleng; return OPLOGICO_NOT; }

{tipos}                     { fprintf(yyout,"Linha %d, Coluna %d: %s (TIPOS)\n", linha, coluna, yytext); coluna += yyleng; return TIPOS;}
{identificador}             { fprintf(yyout,"Linha %d, Coluna %d: %s (ID)\n", linha, coluna, yytext); inserir_simbolo(yytext);; coluna += yyleng; return ID;}

{ponto_virgula}             { fprintf(yyout,"Linha %d, Coluna %d: %s (PONTOVIRGULA)\n", yylineno, coluna, yytext); coluna += yyleng; return PONTOVIRGULA; }
{virgula}                   { fprintf(yyout,"Linha %d, Coluna %d: %s (VIRGULA)\n", yylineno, coluna, yytext); coluna += yyleng; return VIRGULA; }
{parenteses_abre}           { fprintf(yyout,"Linha %d, Coluna %d: %s (ABRE_PAREN)\n", yylineno, coluna, yytext); coluna += yyleng; return ABRE_PAREN; }
{parenteses_fecha}          { fprintf(yyout,"Linha %d, Coluna %d: %s (FECHA_PAREN)\n", yylineno, coluna, yytext); coluna += yyleng; return FECHA_PAREN; }
{chave_abre}                { fprintf(yyout,"Linha %d, Coluna %d: %s (ABRE_CHAVE)\n", yylineno, coluna, yytext); coluna += yyleng; return ABRE_CHAVE; }
{chave_fecha}               { fprintf(yyout,"Linha %d, Coluna %d: %s (FECHA_CHAVE)\n", yylineno, coluna, yytext); coluna += yyleng; return FECHA_CHAVE; }


{comentario_simples}        {}
{comentario_mult} {
    for (int i = 0; yytext[i]; i++) {
        if (yytext[i] == '\n') { linha++; coluna = 1; }
        else coluna++;
    }
} 
{ws}                        { coluna += yyleng; } 
{linha}                     { linha++; coluna = 1; } 
{other}                     { fprintf(yyout, "Lexical error at line %d, column %d. Input -> \"%s\"\n", linha, coluna, yytext); coluna += yyleng; }
                    

%%
/* −−−−−−−−−−−−−−−−−−−−−−−− User subrotines −−−−−−−−−−−−−−−−−−−−−−−−*/
