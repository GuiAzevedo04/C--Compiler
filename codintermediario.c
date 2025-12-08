#include "codintermediario.h"

Instrucao *codigo_ir = NULL;
Instrucao *ultima_instrucao = NULL;
int contador_temp = 0;
int contador_label = 0;

char* novo_temp() {
    char *temp = (char*) malloc(10);
    
    sprintf(temp, "t%d", contador_temp++);

    return temp;
}

char* novo_label() {
    char *label = (char*) malloc(10);
    
    sprintf(label, "L%d", contador_label++);
    
    return label;
}

void adicionar_instrucao(char *op, char *arg1, char *arg2, char *result) {
    Instrucao *nova = (Instrucao*) malloc(sizeof(Instrucao));

    nova->op = strdup(op);
    nova->arg1 = arg1 ? strdup(arg1) : NULL;
    nova->arg2 = arg2 ? strdup(arg2) : NULL;
    nova->result = result ? strdup(result) : NULL;
    nova->prox = NULL;
    
    if (codigo_ir == NULL) {
        codigo_ir = nova;
        ultima_instrucao = nova;
    } else {
        ultima_instrucao->prox = nova;
        ultima_instrucao = nova;
    }
}

void imprimir_codigo_ir() {
    printf("\n========== CÓDIGO INTERMEDIÁRIO (3AC) ==========\n");
    Instrucao *atual = codigo_ir;
    
    if (atual == NULL) {
        printf("  (vazio)\n");
        printf("================================================\n");
        return;
    }
    
    while (atual != NULL) {
        if (strcmp(atual->op, "label") == 0) {
            printf("%s:\n", atual->result);
        } else if (strcmp(atual->op, "goto") == 0) {
            printf("  goto %s\n", atual->result);
        } else if (strcmp(atual->op, "if") == 0) {
            printf("  if %s goto %s\n", atual->arg1, atual->result);
        } else if (strcmp(atual->op, "ifFalse") == 0) {
            printf("  ifFalse %s goto %s\n", atual->arg1, atual->result);
        } else if (strcmp(atual->op, "print") == 0) {
            printf("  print %s\n", atual->arg1);
        } else if (strcmp(atual->op, "read") == 0) {
            printf("  read %s\n", atual->result);
        } else if (strcmp(atual->op, "=") == 0) {
            printf("  %s = %s\n", atual->result, atual->arg1);
        } else if (atual->arg2 == NULL) {
            // Operadores unários: -, +, !
            printf("  %s = %s %s\n", atual->result, atual->op, atual->arg1);
        } else {
            // Operadores binários: +, -, *, /, %, ==, !=, <, <=, >, >=, &&, ||
            printf("  %s = %s %s %s\n", atual->result, atual->arg1, atual->op, atual->arg2);
        }
        atual = atual->prox;
    }
    printf("================================================\n");
}

void liberar_codigo_ir() {
    Instrucao *atual = codigo_ir;
    while (atual != NULL) {
        Instrucao *temp = atual;
        atual = atual->prox;
        
        free(temp->op);
        if (temp->arg1) free(temp->arg1);
        if (temp->arg2) free(temp->arg2);
        if (temp->result) free(temp->result);
        free(temp);
    }
    codigo_ir = NULL;
    ultima_instrucao = NULL;
}