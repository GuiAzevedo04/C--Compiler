#ifndef CODEGEN_H
#define CODEGEN_H

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct Instrucao {
    char *op;        
    char *arg1;      
    char *arg2;      
    char *result;    
    struct Instrucao *prox;
} Instrucao;

extern Instrucao *codigo_ir;
extern Instrucao *ultima_instrucao;
extern int contador_temp;
extern int contador_label;

char* novo_temp();
char* novo_label();
void adicionar_instrucao(char *op, char *arg1, char *arg2, char *result);
void imprimir_codigo_ir();
void liberar_codigo_ir();

#endif