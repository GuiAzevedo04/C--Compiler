%{
    #include <stdio.h>
    #include <stdlib.h>
    #include <string.h>
    #include "codintermediario.h"

    /*declaracoes definidas no analisador lexico*/
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
        char *label_true;    // Para expressões booleanas
        char *label_false;   // Para expressões booleanas
    } Ttype;
}

%code {
    Ttype* criar_ttype(char *tipo, char *valor) {
        Ttype *t = (Ttype*) malloc(sizeof(Ttype));
        t->tipo_semantico = tipo ? strdup(tipo) : NULL;
        t->valor = valor ? strdup(valor) : NULL;
        t->temporario = NULL;
        t->label_true = NULL;
        t->label_false = NULL;
        return t;
    }
}

%union {
    char *sval;
    Ttype *ttype;
}

/* ========== DEFINIÇÃO DOS TOKENS ========== */

%token <sval> NUMERO STRING TRUE_TOKEN FALSE_TOKEN
%token <sval> ID
%token <sval> TIPOS
%type <sval> if_cabecalho 

%type <ttype> expressao fator

%token <sval> OPRELACIONAL                /* ==, !=, <, <=, >, >= */
%token OPLOGICO_OR                  /* || */
%token OPLOGICO_AND                 /* && */
%token ATRIBUICAO                   /* = */         

%token IF ELSE WHILE PRINT READ

%token PONTOVIRGULA VIRGULA         /* ; , */
%token ABRE_CHAVE FECHA_CHAVE       /* { } */
%token ABRE_PAREN FECHA_PAREN       /* ( ) */

/* ========== PRECEDÊNCIA E ASSOCIATIVIDADE ========== */

%right ATRIBUICAO               /* = */
%left OPLOGICO_OR               /* || */
%left OPLOGICO_AND              /* && */
%left OPRELACIONAL              /* ==, !=, <, <=, >, >= */
%left '+' '-'                   /* Soma e Subtração */
%left '*' '/' '%'               /* Multiplicação, Divisão e Módulo */

%right UMINUS                   /* Menos unário: -x */
%right OPLOGICO_NOT             /* Negação lógica: !x */

/* ========== RESOLVER DANGLING ELSE ========== */
%nonassoc LOWER_THAN_ELSE
%nonassoc ELSE

%start inicio

%%

/* ==================== GRAMÁTICA ==================== */

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
    | error PONTOVIRGULA {yyerrok;}
    | error FECHA_CHAVE  {yyerrok;}
    ;

declaracao:
    TIPOS { tipo_atual = $1; } lista_ids PONTOVIRGULA              
    ;

lista_ids:
    ID { inserir_simbolo($1, tipo_atual); }
    | ID ATRIBUICAO expressao { 
        if (!verificar_tipo(tipo_atual, $3->tipo_semantico)) {
            relatar_erro_semantico("Erro na inicialização: Tipos incompatíveis.");
        }
        inserir_simbolo($1, tipo_atual);
        adicionar_instrucao("=", $3->temporario, NULL, $1);
    }
    | lista_ids VIRGULA ID { inserir_simbolo($3, tipo_atual); }
    | lista_ids VIRGULA ID ATRIBUICAO expressao { 
        if (!verificar_tipo(tipo_atual, $5->tipo_semantico)) { 
            relatar_erro_semantico("Erro na inicialização: Tipos incompatíveis.");
        }
        inserir_simbolo($3, tipo_atual);
        adicionar_instrucao("=", $5->temporario, NULL, $3);
    }
    ;

atribuicao:
    ID ATRIBUICAO expressao PONTOVIRGULA {
        Simbolo *s = buscar_simbolo($1);
        if (s == NULL) {
            relatar_erro_semantico("Atribuição: Variável não declarada.");
        } else if (!verificar_tipo(s->tipo, $3->tipo_semantico)) {
            relatar_erro_semantico("Atribuição: Tipos incompatíveis.");
        } else {
            adicionar_instrucao("=", $3->temporario, NULL, $1);
        }
    }                   
    ;

condicional:
    if_cabecalho comando %prec LOWER_THAN_ELSE {
        char *label_fim_then = $<sval>1;  
        adicionar_instrucao("label", NULL, NULL, label_fim_then);
    }
    
    | if_cabecalho comando ELSE {
        char *label_inicio_else = $<sval>1; 
        char *label_fim_if_else = novo_label(); 
        
        adicionar_instrucao("goto", NULL, NULL, label_fim_if_else);
        adicionar_instrucao("label", NULL, NULL, label_inicio_else); 
        
        $<sval>$ = label_fim_if_else; 
    }
    comando {
        char *label_fim = $<sval>4;
        adicionar_instrucao("label", NULL, NULL, label_fim);
    }
    ;

if_cabecalho:
    IF ABRE_PAREN expressao FECHA_PAREN {
        if (!verificar_tipo("bool", $3->tipo_semantico)) {
            relatar_erro_semantico("'if': Condição deve ser do tipo 'bool'.");
        }
        
        char *label_inicio_else = novo_label();
        adicionar_instrucao("ifFalse", $3->temporario, NULL, label_inicio_else);
        
        $<sval>$ = label_inicio_else;
    }
    ;
    
laco:
    WHILE {
        char *label_inicio = novo_label();
        adicionar_instrucao("label", NULL, NULL, label_inicio);
        $<sval>$ = label_inicio; 
    } ABRE_PAREN expressao FECHA_PAREN {
        if (!verificar_tipo("bool", $4->tipo_semantico)) {
            relatar_erro_semantico("'while': Condição deve ser do tipo 'bool'.");
        }
        
        $4->label_true = novo_label();
        $4->label_false = novo_label();
        
        // Se falso, pula para o fim
        adicionar_instrucao("ifFalse", $4->temporario, NULL, $4->label_false);
        adicionar_instrucao("label", NULL, NULL, $4->label_true);
        
        $<sval>$ = $4->label_false;  // Salva label_false
    } comando {
        adicionar_instrucao("goto", NULL, NULL, $<sval>2); 
        adicionar_instrucao("label", NULL, NULL, $<sval>6);
    }
    ;

bloco:
    ABRE_CHAVE { criar_escopo(); } FECHA_CHAVE { excluir_escopo(); }
    | ABRE_CHAVE { criar_escopo(); } lista_comandos FECHA_CHAVE { excluir_escopo(); }
    ;

entrada_saida:
    PRINT ABRE_PAREN lista_expressoes FECHA_PAREN PONTOVIRGULA
    | READ ABRE_PAREN ID FECHA_PAREN PONTOVIRGULA {
        Simbolo *s = buscar_simbolo($3);
        if (s == NULL) {
            relatar_erro_semantico("read(): Variável não declarada.");
        } else {
            adicionar_instrucao("read", NULL, NULL, $3);
        }
    }                
    ;

lista_expressoes:
    expressao {
        adicionar_instrucao("print", $1->temporario, NULL, NULL);
    }
    | lista_expressoes VIRGULA expressao {
        adicionar_instrucao("print", $3->temporario, NULL, NULL);
    }
    ; 

expressao:
    fator { $$ = $1; }
    
    /* ARITMÉTICAS */
    | expressao '+' expressao { 
        if (!verificar_tipo("int", $1->tipo_semantico) || !verificar_tipo("int", $3->tipo_semantico)) { 
            relatar_erro_semantico("Operandos aritméticos devem ser do tipo 'int'."); 
        } 
        $$ = criar_ttype("int", NULL);  
        $$->temporario = novo_temp(); 
        adicionar_instrucao("+", $1->temporario, $3->temporario, $$->temporario); 
    }
    | expressao '-' expressao { 
        if (!verificar_tipo("int", $1->tipo_semantico) || !verificar_tipo("int", $3->tipo_semantico)) { 
            relatar_erro_semantico("Operandos aritméticos devem ser do tipo 'int'."); 
        } 
        $$ = criar_ttype("int", NULL); 
        $$->temporario = novo_temp(); 
        adicionar_instrucao("-", $1->temporario, $3->temporario, $$->temporario); 
    }
    | expressao '*' expressao { 
        if (!verificar_tipo("int", $1->tipo_semantico) || !verificar_tipo("int", $3->tipo_semantico)) { 
            relatar_erro_semantico("Operandos aritméticos devem ser do tipo 'int'."); 
        } 
        $$ = criar_ttype("int", NULL); 
        $$->temporario = novo_temp(); 
        adicionar_instrucao("*", $1->temporario, $3->temporario, $$->temporario); 
    }
    | expressao '/' expressao { 
        if (!verificar_tipo("int", $1->tipo_semantico) || !verificar_tipo("int", $3->tipo_semantico)) { 
            relatar_erro_semantico("Operandos aritméticos devem ser do tipo 'int'."); 
        } 
        $$ = criar_ttype("int", NULL); 
        $$->temporario = novo_temp(); 
        adicionar_instrucao("/", $1->temporario, $3->temporario, $$->temporario); 
    }
    | expressao '%' expressao { 
        if (!verificar_tipo("int", $1->tipo_semantico) || !verificar_tipo("int", $3->tipo_semantico)) { 
            relatar_erro_semantico("Operandos aritméticos devem ser do tipo 'int'."); 
        } 
        $$ = criar_ttype("int", NULL); 
        $$->temporario = novo_temp(); 
        adicionar_instrucao("%", $1->temporario, $3->temporario, $$->temporario); 
    }
    
    /* RELACIONAIS */
    | expressao OPRELACIONAL expressao {
        if (!verificar_tipo("int", $1->tipo_semantico) || !verificar_tipo("int", $3->tipo_semantico)) {
            relatar_erro_semantico("Operandos relacionais (==, <, etc.) devem ser do tipo 'int'.");
        }
        $$ = criar_ttype("bool", NULL);
        $$->temporario = novo_temp();
        // Gera código: temp = arg1 OP arg2
        adicionar_instrucao($2, $1->temporario, $3->temporario, $$->temporario);
    }
    
    /* LÓGICAS */
    | expressao OPLOGICO_AND expressao {
        if (!verificar_tipo("bool", $1->tipo_semantico) || !verificar_tipo("bool", $3->tipo_semantico)) {
            relatar_erro_semantico("Operandos lógicos (&&, ||) devem ser do tipo 'bool'.");
        }
        $$ = criar_ttype("bool", NULL);
        $$->temporario = novo_temp();
        adicionar_instrucao("&&", $1->temporario, $3->temporario, $$->temporario);
    }
    | expressao OPLOGICO_OR expressao {
        if (!verificar_tipo("bool", $1->tipo_semantico) || !verificar_tipo("bool", $3->tipo_semantico)) {
            relatar_erro_semantico("Operandos lógicos (&&, ||) devem ser do tipo 'bool'.");
        }
        $$ = criar_ttype("bool", NULL);
        $$->temporario = novo_temp();
        adicionar_instrucao("||", $1->temporario, $3->temporario, $$->temporario);
    }
    ;

fator:
    NUMERO { 
        $$ = criar_ttype("int", NULL); 
        $$->temporario = $1; 
    }
    | STRING { 
        $$ = criar_ttype("string", NULL); 
        $$->temporario = $1;
    }
    | TRUE_TOKEN { 
        $$ = criar_ttype("bool", NULL); 
        $$->temporario = strdup("true");
    }
    | FALSE_TOKEN { 
        $$ = criar_ttype("bool", NULL); 
        $$->temporario = strdup("false");
    }
    | ID { 
        Simbolo *s = buscar_simbolo($1); 
        if (s == NULL) {
            relatar_erro_semantico("Identificador não declarado.");
            $$ = criar_ttype("erro", NULL);
            $$->temporario = $1;
        } else {
            $$ = criar_ttype(s->tipo, NULL);
            $$->temporario = $1;
        }
    }
    | ABRE_PAREN expressao FECHA_PAREN { 
        $$ = $2; 
    }
    | '-' fator %prec UMINUS { 
        if (!verificar_tipo("int", $2->tipo_semantico)) {
            relatar_erro_semantico("Operador unário '-' aceita apenas 'int'.");
        }
        $$ = criar_ttype("int", NULL);
        $$->temporario = novo_temp();
        adicionar_instrucao("-", $2->temporario, NULL, $$->temporario);
    }
    | '+' fator %prec UMINUS {
        if (!verificar_tipo("int", $2->tipo_semantico)) {
            relatar_erro_semantico("Operador unário '+' aceita apenas 'int'.");
        }
        $$ = criar_ttype("int", NULL);
        $$->temporario = novo_temp();
        adicionar_instrucao("+", $2->temporario, NULL, $$->temporario);
    }
    | OPLOGICO_NOT fator %prec OPLOGICO_NOT {
        if (!verificar_tipo("bool", $2->tipo_semantico)) {
            relatar_erro_semantico("Operador unário '!' aceita apenas 'bool'.");
        }
        $$ = criar_ttype("bool", NULL);
        $$->temporario = novo_temp();
        adicionar_instrucao("!", $2->temporario, NULL, $$->temporario);
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
        imprimir_codigo_ir();
        
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