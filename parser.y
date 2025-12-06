%{
    #include <stdio.h>
    #include <stdlib.h>
    #include <string.h>

    /*declarações definidas no analisador léxico*/
    extern int yylex(void);
    extern int yylineno;
    extern int coluna;
    extern char *yytext;
    extern FILE *yyin;
    extern FILE *yyout;

    typedef struct Simbolo {
        char *lexema;
        char *tipo;      
        struct Simbolo *prox;
    } Simbolo;

    extern Simbolo* buscar_simbolo(char *lexema);
    extern void imprimir_tabela();
    extern void iniciar_analise();
    extern void criar_escopo();
    extern void excluir_escopo();
    extern void inserir_simbolo(char *lexema, char *tipo);

    extern void relatar_erro_semantico(const char *mensagem);
    extern int verificar_tipo(char *tipo_esperado, char *tipo_encontrado);
    
    void yyerror(const char *s);
    int yyparse(void);
    
    char *tipo_atual = NULL;  // Armazena o tipo da declaração atual

%}

%define parse.error verbose

%code requires {
    typedef struct Ttype {
        char *tipo_semantico;
        char *valor;        
        char *temporario;   
    } Ttype;
}

%code {
    Ttype* criar_ttype(char *tipo, char *valor) {
        Ttype *t = (Ttype*) malloc(sizeof(Ttype));
        t->tipo_semantico = tipo ? strdup(tipo) : NULL;
        t->valor = valor ? strdup(valor) : NULL;
        t->temporario = NULL;
        return t;
    }
}

%union {
    char *sval;
    Ttype *ttype;
}

/* ========== DEFINIÇÃO DOS TOKENS ========== */

%token NUMERO STRING
%token <sval> ID
%token <sval> TIPOS

%type <ttype> expressao fator

%token OPRELACIONAL                 /* ==, !=, <, <=, >, >= */
%token OPLOGICO_OR                  /* || */
%token OPLOGICO_AND                 /* && */
%token ATRIBUICAO                   /* = */         

%token IF ELSE WHILE PRINT READ TRUE_TOKEN FALSE_TOKEN

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
    | ID ATRIBUICAO expressao { 
        if (!verificar_tipo(tipo_atual, $3->tipo_semantico)) {
            relatar_erro_semantico("Erro na inicialização: Tipos incompatíveis.");
        }
        inserir_simbolo($1, tipo_atual);
    }
    | lista_ids VIRGULA ID { inserir_simbolo($3, tipo_atual); }
    | lista_ids VIRGULA ID ATRIBUICAO expressao { 
        if (!verificar_tipo(tipo_atual, $5->tipo_semantico)) { 
            relatar_erro_semantico("Erro na inicialização: Tipos incompatíveis.");
        }
        inserir_simbolo($3, tipo_atual);
    }
    ;

atribuicao:
    ID ATRIBUICAO expressao PONTOVIRGULA {                  /* Ex: x = y + 1; */
        Simbolo *s = buscar_simbolo($1);
        if (s == NULL) {
            relatar_erro_semantico("Atribuição: Variável não declarada.");
        } else if (!verificar_tipo(s->tipo, $3->tipo_semantico)) {
            relatar_erro_semantico("Atribuição: Tipos incompatíveis.");
        }
    }                   
    ;

condicional:
    IF ABRE_PAREN expressao FECHA_PAREN comando %prec LOWER_THAN_ELSE {
        if (!verificar_tipo("bool", $3->tipo_semantico)) {
            relatar_erro_semantico("'if': Condição deve ser do tipo 'bool'.");
        }
    }
    | IF ABRE_PAREN expressao FECHA_PAREN comando ELSE comando {
        if (!verificar_tipo("bool", $3->tipo_semantico)) {
            relatar_erro_semantico("'if': Condição deve ser do tipo 'bool'.");
        }
    }
    ;

laco:
    WHILE ABRE_PAREN expressao FECHA_PAREN comando {
        if (!verificar_tipo("bool", $3->tipo_semantico)) {
            relatar_erro_semantico("'while': Condição deve ser do tipo 'bool'.");
        }
    }
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
    fator { $$ = $1; }
    /* ARITMÉTICAS */
    | expressao '+' expressao { if (!verificar_tipo("int", $1->tipo_semantico) || !verificar_tipo("int", $3->tipo_semantico)) { relatar_erro_semantico("Operandos aritméticos devem ser do tipo 'int'."); } $$ = criar_ttype("int", NULL); }
    | expressao '-' expressao { if (!verificar_tipo("int", $1->tipo_semantico) || !verificar_tipo("int", $3->tipo_semantico)) { relatar_erro_semantico("Operandos aritméticos devem ser do tipo 'int'."); } $$ = criar_ttype("int", NULL); }
    | expressao '*' expressao { if (!verificar_tipo("int", $1->tipo_semantico) || !verificar_tipo("int", $3->tipo_semantico)) { relatar_erro_semantico("Operandos aritméticos devem ser do tipo 'int'."); } $$ = criar_ttype("int", NULL); }
    | expressao '/' expressao { if (!verificar_tipo("int", $1->tipo_semantico) || !verificar_tipo("int", $3->tipo_semantico)) { relatar_erro_semantico("Operandos aritméticos devem ser do tipo 'int'."); } $$ = criar_ttype("int", NULL); }
    | expressao '%' expressao { if (!verificar_tipo("int", $1->tipo_semantico) || !verificar_tipo("int", $3->tipo_semantico)) { relatar_erro_semantico("Operandos aritméticos devem ser do tipo 'int'."); } $$ = criar_ttype("int", NULL); }
    /* RELACIONAIS */
    | expressao OPRELACIONAL expressao {
        if (!verificar_tipo("int", $1->tipo_semantico) || !verificar_tipo("int", $3->tipo_semantico)) {
            relatar_erro_semantico("Operandos relacionais (==, <, etc.) devem ser do tipo 'int'.");
        }
        $$ = criar_ttype("bool", NULL);
    }
    /* LÓGICAS */
    | expressao OPLOGICO_AND expressao {
        if (!verificar_tipo("bool", $1->tipo_semantico) || !verificar_tipo("bool", $3->tipo_semantico)) {
            relatar_erro_semantico("Operandos lógicos (&&, ||) devem ser do tipo 'bool'.");
        }
        $$ = criar_ttype("bool", NULL);
    }
    | expressao OPLOGICO_OR expressao {
        if (!verificar_tipo("bool", $1->tipo_semantico) || !verificar_tipo("bool", $3->tipo_semantico)) {
            relatar_erro_semantico("Operandos lógicos (&&, ||) devem ser do tipo 'bool'.");
        }
        $$ = criar_ttype("bool", NULL);
    }
    ;

fator:
    NUMERO { $$ = criar_ttype("int", NULL); }
    | STRING { $$ = criar_ttype("string", NULL); }
    | TRUE_TOKEN { $$ = criar_ttype("bool", NULL); }
    | FALSE_TOKEN { $$ = criar_ttype("bool", NULL); }
    | ID { 
        Simbolo *s = buscar_simbolo($1); 
        if (s == NULL) {
            relatar_erro_semantico("Identificador não declarado.");
            $$ = criar_ttype("erro", NULL);
        } else {
            $$ = criar_ttype(s->tipo, NULL);
        }
    }
    | ABRE_PAREN expressao FECHA_PAREN { $$ = $2; }
    | '-' fator %prec UMINUS { 
        if (!verificar_tipo("int", $2->tipo_semantico)) {
            relatar_erro_semantico("Operador unário '-' aceita apenas 'int'.");
        }
        $$ = criar_ttype("int", NULL);
    }
    | '+' fator %prec UMINUS {
        if (!verificar_tipo("int", $2->tipo_semantico)) {
            relatar_erro_semantico("Operador unário '+' aceita apenas 'int'.");
        }
        $$ = criar_ttype("int", NULL);
    }
    | OPLOGICO_NOT fator %prec OPLOGICO_NOT {
        if (!verificar_tipo("bool", $2->tipo_semantico)) {
            relatar_erro_semantico("Operador unário '!' aceita apenas 'bool'.");
        }
        $$ = criar_ttype("bool", NULL);
    }
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