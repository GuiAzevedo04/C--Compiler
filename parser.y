%{
    #include <stdio.h>
    #include <stdlib.h>

    /*declaracoes definidas no analisador lexico*/
    extern int yylex(void);
    extern int yylineno;
    extern int coluna;
    extern char *yytext;
    extern FILE *yyin;
    extern FILE *yyout;
    extern void imprimir_tabela();
    
    void yyerror(const char *s);
    int yyparse(void);
%}

%define parse.error verbose

/* ========== DEFINIÇÃO DOS TOKENS ========== */

%token NUMERO STRING
%token ID

%token OPRELACIONAL                 /* ==, !=, <, <=, >, >= */
%token OPLOGICO_OR                  /* || */
%token OPLOGICO_AND                 /* && */
%token ATRIBUICAO                   /* = */         

%token TIPOS                        /* int, bool */

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
%left '*' '/' '%'               * Multiplicação, Divisão e Módulo */

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
    TIPOS lista_ids PONTOVIRGULA              
    | TIPOS lista_ids error PONTOVIRGULA      {yyerrok;}        /* RECUPERAÇÃO: Descarta até o próximo ';' */
    ;


lista_ids:
    ID
    | ID ATRIBUICAO expressao                              /* Ex: x = 5 */
    | lista_ids VIRGULA ID                                 /* Ex: x, y */
    | lista_ids VIRGULA ID ATRIBUICAO expressao            /* Ex: x, y = 10 */
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
    ABRE_CHAVE FECHA_CHAVE                              /* bloco vazio: {} */
    | ABRE_CHAVE lista_comandos FECHA_CHAVE             /* bloco com comandos */
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
    fprintf(stderr, "=============== ERRO SINTÁTICO DETECTADO =============== \n");
    fprintf(stderr, "Linha:  %d\n", yylineno);
    fprintf(stderr, "Coluna: %d\n", coluna);
    fprintf(stderr, "Informação do erro: %s \n", s);
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

    if (argc > 2) {
        yyout = fopen(argv[2], "w");
        if (!yyout) {
            fprintf(stderr, "Erro ao criar arquivo de saída: %s\n", argv[2]);
            return 1;
        }
        printf("Saída dos tokens em: %s\n", argv[2]);
    } else {
        yyout = stdout;
    }

    printf("\n ============== ANALISADOR INICIADO  ============== \n");
    
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