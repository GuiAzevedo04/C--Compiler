%{
    #include <stdio.h>
    #include <stdlib.h>
    #include <string.h>

    /*declaracoes definidas no analisador lexico*/
    extern int yylex(void);
    extern int yylineno;
    extern int coluna;
    extern char *yytext;
    extern FILE *yyin;
    extern FILE *yyout;
    extern void imprimir_tabela();
    extern void iniciar_analise();
    extern void criar_escopo();
    extern void excluir_escopo();
    extern void inserir_simbolo(char *lexema, char *tipo);
    
    void yyerror(const char *s);
    int yyparse(void);
    
    char *tipo_atual = NULL;  // Armazena o tipo da declaração atual
%}

%define parse.error verbose

%union {
    char *sval;
}

/* ========== DEFINIÇÃO DOS TOKENS ========== */

%token NUMERO STRING
%token <sval> ID
%token <sval> TIPOS

%token OPRELACIONAL                 /* ==, !=, <, <=, >, >= */
%token OPLOGICO_OR                  /* || */
%token OPLOGICO_AND                 /* && */
%token ATRIBUICAO                   /* = */         

%token IF ELSE WHILE PRINT READ

%token PONTOVIRGULA VIRGULA         /* ; , */
%token ABRE_CHAVE FECHA_CHAVE       /* { } */
%token ABRE_PAREN FECHA_PAREN       /* ( ) */

/* ========== PRECEDÊNCIA E ASSOCIATIVIDADE ========== */
/* Ordem: do menor para o maior (de baixo para cima na execução) */

%right ATRIBUICAO               /* = (Associatividade à direita para a cadeia a = b = c) */
%left OPLOGICO_OR               /* || */
%left OPLOGICO_AND              /* && */
%left OPRELACIONAL              /* ==, !=, <, <=, >, >= */
%left '+' '-'                   /* Soma e Subtração */
%left '*' '/' '%'               /* Multiplicação, Divisão e Módulo */

%right UMINUS                   /* Menos unário: -x */
%right OPLOGICO_NOT             /* Negação lógica: !x (maior precedência) */

/* ========== RESOLVER DANGLING ELSE ========== */
/* Garante que o else deve se associar ao if mais próximo */
%nonassoc LOWER_THAN_ELSE
%nonassoc ELSE

%start inicio

%%

/* ==================== GRAMÁTICA ==================== */
/*Ponto de entrada: a gramática é uma lista de comandos*/
inicio: 
    lista_comandos
    ;

lista_comandos:
    comando
    | lista_comandos comando
    ;

comando:
    declaracao
    | atribuicao
    | condicional
    | laco
    | bloco
    | entrada_saida
    | PONTOVIRGULA                                                                                        
    | error PONTOVIRGULA {yyerrok;}         /* RECUPERAÇÃO: Descarta até o próximo ';' */
    | error FECHA_CHAVE  {yyerrok;}         /* RECUPERAÇÃO: Para erros antes de fechar um bloco */
    ;

declaracao:
    TIPOS { tipo_atual = $1; } lista_ids PONTOVIRGULA              
    // | TIPOS { tipo_atual = $1; } lista_ids error PONTOVIRGULA { yyerrok; }
    ;


lista_ids:
    ID { inserir_simbolo($1, tipo_atual); }
    | ID ATRIBUICAO expressao { inserir_simbolo($1, tipo_atual); }
    | lista_ids VIRGULA ID { inserir_simbolo($3, tipo_atual); }
    | lista_ids VIRGULA ID ATRIBUICAO expressao { inserir_simbolo($3, tipo_atual); }
    ;

atribuicao:
    ID ATRIBUICAO expressao PONTOVIRGULA                   /* Ex: x = y + 1; */
    ;

condicional:
    IF ABRE_PAREN expressao FECHA_PAREN comando %prec LOWER_THAN_ELSE
    | IF ABRE_PAREN expressao FECHA_PAREN comando ELSE comando
    ;

laco:
    WHILE ABRE_PAREN expressao FECHA_PAREN comando
    ;

bloco:
    ABRE_CHAVE { criar_escopo(); } FECHA_CHAVE { excluir_escopo(); }
    | ABRE_CHAVE { criar_escopo(); } lista_comandos FECHA_CHAVE { excluir_escopo(); }
    ;

entrada_saida:
    PRINT ABRE_PAREN lista_expressoes FECHA_PAREN PONTOVIRGULA      /* Ex: print(x, "valor"); */
    | READ ABRE_PAREN ID FECHA_PAREN PONTOVIRGULA                   /* Ex: read(y); */
    ;

 lista_expressoes:
    expressao
    | lista_expressoes VIRGULA expressao
    ; 

expressao:
    fator
    /* ARITMÉTICAS */
    | expressao '+' expressao
    | expressao '-' expressao
    | expressao '*' expressao
    | expressao '/' expressao
    | expressao '%' expressao
    /* RELACIONAIS */
    | expressao OPRELACIONAL expressao
    /* LÓGICAS */
    | expressao OPLOGICO_AND expressao
    | expressao OPLOGICO_OR expressao
    ;

fator:
    NUMERO
    | STRING
    | ID
    | ABRE_PAREN expressao FECHA_PAREN
    | '-' fator %prec UMINUS
    | '+' fator %prec UMINUS
    | OPLOGICO_NOT fator %prec OPLOGICO_NOT
    ;

%%

/* ========== IMPLEMENTAÇÃO DAS FUNÇÕES ========== */

void yyerror(const char *s) {
    fprintf(stderr, "Linha:  %d\n", yylineno);
    fprintf(stderr, "Coluna: %d\n", coluna);
    fprintf(stderr, "Informação do erro: %s \n", s);
    fprintf(stderr, "Erro sintático: (Linha %d, Coluna %d)\n",  yylineno, coluna);
    fprintf(stderr, "Texto encontrado: %s \n", yytext);
    fprintf(stderr, "\n\n");
}

int main(int argc, char **argv) {
    if (argc > 1) {
        yyin = fopen(argv[1], "r");
        if (!yyin) {
            fprintf(stderr, "Erro ao abrir arquivo: %s\n", argv[1]);
            return 1;
        }
        printf("Lendo arquivo: %s\n", argv[1]);
    } else {
        printf("Lendo da entrada padrão (stdin)\n");
        yyin = stdin;
    }

    printf("\n ============== ANALISADOR INICIADO  ============== \n");
    
    iniciar_analise();  // Cria o escopo global
    
    int resultado = yyparse();
    
    if (resultado == 0) {
        printf("\n ============== ANÁLISE FINALIZADA COM SUCESSO ============== \n");
        imprimir_tabela();
        
        if (yyin != stdin) fclose(yyin);
        if (yyout != stdout) fclose(yyout);
        return 0;
    } else {
        printf("\n ============== ANÁLISE FINALIZADA COM ERROS ENCONTRADOS ============== \n");
        
        if (yyin != stdin) fclose(yyin);
        if (yyout != stdout) fclose(yyout);
        return 1;
    }
}