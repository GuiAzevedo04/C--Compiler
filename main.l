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
    char *tipo;      
    struct Simbolo *prox;  // lista encadeada em caso de colisão
} Simbolo;

typedef struct Escopo {
    Simbolo *tabela[HASH_SIZE];
    struct Escopo *anterior;  /* Ponteiro para o escopo pai */
    int nivel;                
} Escopo;

/* Variável Global que aponta para o topo da pilha de escopos */
Escopo *escopo_atual = NULL;
int nivel_global = 0;

unsigned int hash(char *lexema) {
    unsigned int h = 0;
    for (int i = 0; lexema[i] != '\0'; i++) {
        h = h * 37 + lexema[i];  // multiplica por um número primo e soma o caractere
    }
    return h % HASH_SIZE;        // garante que caia dentro da tabela
}

/* Chamada quando encontra '{' */
void criar_escopo() {
    Escopo *novo = (Escopo *) malloc(sizeof(Escopo));
    for (int i = 0; i < HASH_SIZE; i++) {
        novo->tabela[i] = NULL;
    }
    novo->anterior = escopo_atual;
    novo->nivel = nivel_global++;
    escopo_atual = novo;
    printf("Novo Escopo Criado (Nivel %d)\n", novo->nivel);
}

/* Chamada quando encontra '}' */
void excluir_escopo() {
    if (escopo_atual == NULL) return;
    
    printf("Fechando Escopo (Nivel %d)\n", escopo_atual->nivel);
    
    Escopo *velho = escopo_atual;
    escopo_atual = escopo_atual->anterior;
    nivel_global--;
    
    // Libera os símbolos do escopo sendo fechado
    for (int i = 0; i < HASH_SIZE; i++) {
        Simbolo *s = velho->tabela[i];
        while (s != NULL) {
            Simbolo *temp = s;
            s = s->prox;
            free(temp->lexema);
            free(temp->tipo);
            free(temp);
        }
    }
    
    free(velho);
}

void inserir_simbolo(char *lexema, char *tipo) {
    if (escopo_atual == NULL) {
        criar_escopo(); // Garante que existe ao menos um escopo global
    }

    unsigned int idx = hash(lexema);
    Simbolo *s = escopo_atual->tabela[idx];

    // verifica se já existe no escopo atual
    while (s != NULL) {
        if (strcmp(s->lexema, lexema) == 0) {
            fprintf(stderr, "Erro semântico: (Linha %d, Coluna %d): Variavel '%s' ja declarada neste escopo.\n", 
                    linha, coluna, lexema);
            return; 
        }
        s = s->prox;
    }

    // cria novo símbolo
    Simbolo *novo = (Simbolo *) malloc(sizeof(Simbolo));
    novo->lexema = strdup(lexema);
    novo->tipo = strdup(tipo);
    novo->prox = escopo_atual->tabela[idx];
    escopo_atual->tabela[idx] = novo;

    printf("Declarado '%s' (tipo: %s) no escopo nivel %d\n", lexema, tipo, escopo_atual->nivel);
}

Simbolo* buscar_simbolo(char *lexema) {
    Escopo *esc = escopo_atual;
    
    // Busca em todos os escopos, do mais interno para o mais externo
    while (esc != NULL) {
        unsigned int idx = hash(lexema);
        Simbolo *s = esc->tabela[idx];
        
        while (s != NULL) {
            if (strcmp(s->lexema, lexema) == 0) {
                return s;  // Encontrou
            }
            s = s->prox;
        }
        
        esc = esc->anterior;  // Vai para o escopo pai
    }
    
    return NULL;  // Não encontrou em nenhum escopo
}

void imprimir_tabela() {
    printf("\n=== TABELA DE SIMBOLOS (TODOS OS ESCOPOS) ===\n");
    
    Escopo *esc = escopo_atual;
    while (esc != NULL) {
        printf("\n--- Escopo Nivel %d ---\n", esc->nivel);
        
        for (int i = 0; i < HASH_SIZE; i++) {
            Simbolo *atual = esc->tabela[i];
            while (atual != NULL) {
                printf(" (identificador: %s)  (tipo: %s)\n", atual->lexema, atual->tipo);
                atual = atual->prox;
            }
        }
        
        esc = esc->anterior;
    }
    printf("\n");
}

void iniciar_analise() {
    criar_escopo();  // Cria o escopo global
}


void relatar_erro_semantico(const char *mensagem) {
    fprintf(stderr, "Erro semântico: (Linha %d, Coluna %d): %s\n", 
            linha, coluna, mensagem);
}

// Retorna 1 se o tipo é compatível, 0 caso contrário
int verificar_tipo(char *tipo_esperado, char *tipo_encontrado) {
    // Se o tipo esperado ou encontrado for "erro", ignora (para evitar cascata)
    if (tipo_encontrado == NULL || tipo_esperado == NULL || 
        strcmp(tipo_encontrado, "erro") == 0) {
        return 1; 
    }
    // Para atribuição, se o tipo for string, exigimos correspondência exata.
    // Se for int/bool, vamos assumir que o sistema de tipos é estrito: int == int, bool == bool.
    return (strcmp(tipo_esperado, tipo_encontrado) == 0);
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
"true"                      { coluna += yyleng; return TRUE_TOKEN; }
"false"                      { coluna += yyleng; return FALSE_TOKEN; }

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

{tipos}                     { yylval.sval = strdup(yytext); coluna += yyleng; return TIPOS;}
{identificador}             { yylval.sval = strdup(yytext); coluna += yyleng; return ID;}

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
{other}                     { fprintf(yyout, "Erro léxico: linha %d, coluna %d. Input -> \"%s\"\n", linha, coluna, yytext); coluna += yyleng; }
                    

%%
