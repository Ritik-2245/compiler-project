%{
    #include <stdio.h>
    #include <stdlib.h>
    #include <stdarg.h>
    #include <string.h>    //gcc -o wind lex.yy.c rkv.tab.c 
    #include <time.h>
    #include <math.h>
    #include "rkv.h"

    #define YYDEBUG 0

    int getIndex(char *id, char mode);      /* Returns index from symbol table */
    nodeType *id(char *vName, char mode);   /* Identifier type node */
    nodeType *cond(double dValue);          /* Constant double type node */
    nodeType *cons(char *sValue);           /* Constant string type node */
    nodeType *opr(int oper, int nops, ...); /* Operator type node */
    void freeNode(nodeType *p);             /* Free the node */
    double ex(nodeType *p);                 /* Execute graph */
    int yylex(void);

    void yyerror(char *);
    double sym[SYMSIZE];        /* Symbol table */
    char vars[SYMSIZE][IDLEN];  /* Variable table: for mapping variables to symbol table */
    unsigned int seed;
%}

%union {
    double dValue;
    char *sValue;
    char *vName;
    nodeType *nPtr;
}

%token <dValue> NUMBER
%token <vName> VARIABLE
%token <sValue> STRING
%token IF THEN PRINT ASSIGN RANDOM PI SCAN ABS EXIT
%nonassoc IFX
%nonassoc ELSE

%left AND OR
%left GE LE '=' NE '>' '<'
%left '+' '-'
%left '*' '/' '%'
%left NOT
%left '^'
%nonassoc UMINUS

%type <nPtr> statement expression statement_list

%%
program : function { exit(0); }
        ;

function : 
         | function statement { ex($2); freeNode($2); }
         ;

statement : ';' { $$ = opr(';', 2, NULL, NULL); }
          | expression ';' { $$ = $1; }
          | EXIT ';' { exit(0); }
          | VARIABLE ASSIGN expression ';' { $$ = opr(ASSIGN, 2, id($1, SET), $3); }
          | PRINT expression ';' { $$ = opr(PRINT, 1, $2); }
          | PRINT STRING ';' { $$ = opr(PRINT, 1, cons($2)); }
          | SCAN VARIABLE ';' { $$ = opr(SCAN, 1, id($2, GET)); }
          | IF expression THEN statement %prec IFX { $$ = opr(IF, 2, $2, $4); }
          | IF expression THEN statement ELSE statement { $$ = opr(IF, 3, $2, $4, $6); }
          | '{' statement_list '}' { $$ = $2; }
          ;

statement_list : statement { $$ = $1; }
               | statement_list statement { $$ = opr(';', 2, $1, $2); }
               ;

expression : NUMBER { $$ = cond($1); }
           | VARIABLE { $$ = id($1, GET); }
           | PI { $$ = opr(PI, 0); }
           | ABS '(' expression ')' { $$ = opr(ABS, 1, $3); }
           | '-' expression %prec UMINUS { $$ = opr(UMINUS, 1, $2); }
           | expression '^' expression { $$ = opr('^', 2, $1, $3); }
           | expression '+' expression { $$ = opr('+', 2, $1, $3); }
           | expression '-' expression { $$ = opr('-', 2, $1, $3); }
           | expression '*' expression { $$ = opr('*', 2, $1, $3); }
           | expression '/' expression { $$ = opr('/', 2, $1, $3); }
           | expression '%' expression { $$ = opr('%', 2, $1, $3); }
           | expression '<' expression { $$ = opr('<', 2, $1, $3); }
           | expression '>' expression { $$ = opr('>', 2, $1, $3); }
           | expression GE expression { $$ = opr(GE, 2, $1, $3); }
           | expression LE expression { $$ = opr(LE, 2, $1, $3); }
           | expression '=' expression { $$ = opr('=', 2, $1, $3); }
           | expression NE expression { $$ = opr(NE, 2, $1, $3); }
           | expression AND expression { $$ = opr(AND, 2, $1, $3); }
           | expression OR expression { $$ = opr(OR, 2, $1, $3); }
           | NOT expression { $$ = opr(NOT, 1, $2); }
           | '(' expression ')' { $$ = $2; }
           ;
%%

int getIndex(char *id, char mode)
{
    /* Returns the variable index from symbol table */
    switch (mode) {
        case GET:       /* Return index of variable from symbol table */
        {
            for (int i = 0; i < SYMSIZE; i++) {
                if (!strcmp(vars[i], "-1")) return -1;
                else if (!strcmp(id, vars[i])) return i;    /* ID found */
            }
            return -1;
        }
        case SET:       /* Sets the index of variable from symbol table and then returns the index */
        {
            for (int i = 0; i < SYMSIZE; i++) {
                if (!strcmp(id, vars[i])) return i;     /* ID already exists */
                else if (!strcmp(vars[i], "-1")) {
                    strcpy(vars[i], id);
                    return i;
                }
            }
            return -1;
        }
    }
}

nodeType *id(char *vName, char mode) {
    int sIndex = getIndex(vName, mode);
    if (sIndex == -1 && mode == GET) {
        yyerror("variable not initialized");
        exit(1);
    }
    else if (sIndex == -1 && mode == SET) {
        yyerror("failed to initialize variable");
        exit(1);
    }

    nodeType *p;
     
    /* allocate node */
    if ((p = malloc(sizeof(nodeType))) == NULL)
        yyerror("out of memory");

    /* copy information */
    p->type = typeId;
    p->id.i = sIndex;

    return p;
}

nodeType *cond(double dValue) {
    nodeType *p;
     
    /* allocate node */
    if ((p = malloc(sizeof(nodeType))) == NULL)
        yyerror("out of memory");

    /* copy information */
    p->type = typeCon;
    p->con.type = typeNum;
    p->con.dValue = dValue;

    return p;
}

nodeType *cons(char *sValue) {
    nodeType *p;
     
    /* allocate node */
    if ((p = malloc(sizeof(nodeType))) == NULL)
        yyerror("out of memory");

    /* copy information */
    p->type = typeCon;
    p->con.type = typeStr;
    p->con.sValue = strdup(sValue);

    return p;
}

nodeType *opr(int oper, int nops, ...) {
    va_list ap;
    nodeType *p;
     
    /* allocate node */
    if ((p = malloc(sizeof(nodeType))) == NULL)
        yyerror("out of memory");
    if ((p->opr.op = malloc(nops * sizeof(nodeType *))) == NULL)
        yyerror("out of memory");

    /* copy information */
    p->type = typeOpr;
    p->opr.oper = oper;
    p->opr.nops = nops;
    
    va_start(ap, nops);
    for (int i = 0; i < nops; i++) 
        p->opr.op[i] = va_arg(ap, nodeType *);
    va_end(ap);

    return p;
}

void freeNode(nodeType *p) {
    if (!p) return;
    if (p->type == typeOpr) {
        for (int i = 0; i < p->opr.nops; i++)
            freeNode(p->opr.op[i]);
        free(p->opr.op);
    }
    free(p);
}

double ex(nodeType *p) {
    if (!p) return 0;

    switch (p->type) {
        case typeCon: return p->con.dValue;
        case typeId: return sym[p->id.i];
        case typeOpr:
            switch (p->opr.oper) {
                case IF:
                    if (ex(p->opr.op[0]))
                        ex(p->opr.op[1]);
                    else if (p->opr.nops > 2)
                        ex(p->opr.op[2]);
                    return 0;
                case PRINT:
                    if (p->opr.op[0]->type == typeCon && p->opr.op[0]->con.type == typeStr) {
                        char *sValue = p->opr.op[0]->con.sValue;
                        int i, slen = strlen(sValue);
                        for (i = 0; i < slen-1; i++) {
                            if (sValue[i] == '\\' && sValue[i+1] == 'n') {
                                printf("\n");
                                i++;
                            }
                            else if (sValue[i] == '\\' && sValue[i+1] == 't') {
                                printf("\t");
                                i++;
                            }
                            else printf("%c", sValue[i]);
                        }
                        if (i == slen-1) printf("%c", sValue[i]);
                        return 0;
                    }
                    else {
                        double dValue = ex(p->opr.op[0]);
                        if (dValue == floor(dValue)) printf("%d", (int)dValue);
                        else if (dValue - floor(dValue) < 1e-6) printf("%e", dValue);
                        else printf("%lf", dValue);
                        return 0;
                    }
                case SCAN:
                {
                    double dValue;
                    printf(">>> ");
                    scanf("%lf", &dValue);
                    return sym[p->opr.op[0]->id.i] = dValue;
                }
                
                
                case ABS: return fabs(ex(p->opr.op[0]));
                case PI: return M_PI;
                case ';':
                    ex(p->opr.op[0]);
                    return ex(p->opr.op[1]);
                case ASSIGN: return sym[p->opr.op[0]->id.i] = ex(p->opr.op[1]);
                case UMINUS: return -ex(p->opr.op[0]);
                case '^': return pow(ex(p->opr.op[0]), ex(p->opr.op[1]));
                case '+': return ex(p->opr.op[0]) + ex(p->opr.op[1]);
                case '-': return ex(p->opr.op[0]) - ex(p->opr.op[1]);
                case '*': return ex(p->opr.op[0]) * ex(p->opr.op[1]);
                case '/': return ex(p->opr.op[0]) / ex(p->opr.op[1]);
                case '%': return (int)ex(p->opr.op[0]) % (int)ex(p->opr.op[1]);
                case '>': return ex(p->opr.op[0]) > ex(p->opr.op[1]);
                case '<': return ex(p->opr.op[0]) < ex(p->opr.op[1]);
                case GE: return ex(p->opr.op[0]) >= ex(p->opr.op[1]);
                case LE: return ex(p->opr.op[0]) <= ex(p->opr.op[1]);
                case '=': return ex(p->opr.op[0]) == ex(p->opr.op[1]);
                case NE: return ex(p->opr.op[0]) != ex(p->opr.op[1]);
                case AND: return (int)ex(p->opr.op[0]) && (int)ex(p->opr.op[1]);
                case OR: return (int)ex(p->opr.op[0]) || (int)ex(p->opr.op[1]);
                case NOT: return !(int)ex(p->opr.op[0]);
            }
    }
    return 0;
}

int main(int argc, char **argv) {
    #if YYDEBUG
        yydebug = 1;
    #endif

    seed = time(NULL);

    /* Initialize variable table */
    for (int i = 0; i < SYMSIZE; i++) strcpy(vars[i], "-1");

    if (argc < 2)
        yyparse();
    else {
        freopen(argv[1], "r", stdin);
        yyparse();
    }

    return 0;
}