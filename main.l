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

"if"                        { coluna += yyleng; return IF; }
"else"                      { coluna += yyleng; return ELSE; }
"while"                     { coluna += yyleng; return WHILE; }
"print"                     { coluna += yyleng; return PRINT; }
"read"                      { coluna += yyleng; return READ; }

{numero_inteiro}            { coluna += yyleng; return NUMERO; }
{string}                    { coluna += yyleng; return STRING; }
{op_relacional}             { coluna += yyleng; return OPRELACIONAL;}

{atribuicao}                { coluna += yyleng; return ATRIBUICAO;}

"+"                         { coluna += yyleng; return '+'; }
"-"                         { coluna += yyleng; return '-'; }
"*"                         { coluna += yyleng; return '*'; }
"/"                         { coluna += yyleng; return '/'; }
"%"                         { coluna += yyleng; return '%'; }


{op_logico_and}             { coluna += yyleng; return OPLOGICO_AND; }
{op_logico_or}              { coluna += yyleng; return OPLOGICO_OR; }
{op_logico_not}             { coluna += yyleng; return OPLOGICO_NOT; }

{tipos}                     { coluna += yyleng; return TIPOS;}
{identificador}             { inserir_simbolo(yytext);; coluna += yyleng; return ID;}

{ponto_virgula}             { coluna += yyleng; return PONTOVIRGULA; }
{virgula}                   { coluna += yyleng; return VIRGULA; }
{parenteses_abre}           { coluna += yyleng; return ABRE_PAREN; }
{parenteses_fecha}          { coluna += yyleng; return FECHA_PAREN; }
{chave_abre}                { coluna += yyleng; return ABRE_CHAVE; }
{chave_fecha}               { coluna += yyleng; return FECHA_CHAVE; }


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
