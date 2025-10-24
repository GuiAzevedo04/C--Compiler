%option noyywrap

%{

/* −−−−−−−−−−−−−−−−−−−−−−−−−− D e f i n i t i o n s −−−−−−−−−−−−−−−−−−−−−−−−−− */
#include<stdio.h>
#include <string.h>
#include <stdlib.h>

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

op_relacional           "=="|"!="|"<"|"<="|">"|">="
atribuicao              "="
op_aritmetico           "+"|"-"|"*"|"/"|"**"|"%"
op_logico               "&&"|"||"|"!"

palavras_reservadas     "if"|"else"|"while"|"print"|"read"|"true"|"false"
tipos                   "int"|"bool"

pontuacao               ";"|","|"("|")"|"{"|"}"

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

{numero_inteiro}            { fprintf(yyout,"Linha %d, Coluna %d: %s (NUMERO)\n", linha, coluna, yytext); coluna += yyleng; }
{op_relacional}             { fprintf(yyout,"Linha %d, Coluna %d: %s (OPRELACIONAL)\n", linha, coluna, yytext); coluna += yyleng; }
{atribuicao}                { fprintf(yyout,"Linha %d, Coluna %d: %s (ATRIBUICAO)\n", linha, coluna, yytext); coluna += yyleng;}
{op_aritmetico}             { fprintf(yyout,"Linha %d, Coluna %d: %s (OPARITMETICO)\n", linha, coluna, yytext); coluna += yyleng; }
{op_logico}                 { fprintf(yyout,"Linha %d, Coluna %d: %s (OPLOGICO)\n", linha, coluna, yytext); coluna += yyleng; }
{palavras_reservadas}       { fprintf(yyout,"Linha %d, Coluna %d: %s (PALAVRASRESERVADAS)\n", linha, coluna, yytext); coluna += yyleng; }
{tipos}                     { fprintf(yyout,"Linha %d, Coluna %d: %s (TIPOS)\n", linha, coluna, yytext); coluna += yyleng; }
{identificador}             { fprintf(yyout,"Linha %d, Coluna %d: %s (ID)\n", linha, coluna, yytext); inserir_simbolo(yytext);; coluna += yyleng;}
{pontuacao}                 { fprintf(yyout,"Linha %d, Coluna %d: %s (PONTUACAO)\n", linha, coluna, yytext); coluna += yyleng;}
{comentario_simples}        {}
{comentario_mult} {
    for (int i = 0; yytext[i]; i++) {
        if (yytext[i] == '\n') { linha++; coluna = 1; }
        else coluna++;
    }
}
{ws}                        { coluna += yyleng; } 
{linha}                     { linha++; coluna = 1; } 
{other}                   { fprintf(yyout, "Lexical error at line %d, column %d. Input -> \"%s\"\n", linha, coluna, yytext); coluna += yyleng; }
                    

%%
/* −−−−−−−−−−−−−−−−−−−−−−−− User subrotines −−−−−−−−−−−−−−−−−−−−−−−−*/
int main(int argc, char *argv[]) {
    if (argc < 2) {
        printf("Uso: %s <arquivo-fonte>\n", argv[0]);
        return 1;
    }

    yyin = fopen(argv[1], "r");
    if (!yyin) {
        perror("Erro ao abrir arquivo");
        return 1;
    }

    yyout = stdout;
    yylex();
    fclose(yyin);

    imprimir_tabela();
    return 0;

}
