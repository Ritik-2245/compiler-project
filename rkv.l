%{
    #include <stdlib.h>
    #include <string.h>
    #include "rkv.h"
    #include "rkv.tab.h"

    void yyerror(char *s);
    int lineno = 0;
%}

ID      [a-zA-Z][a-z0-9A-Z_]*
EXPO    [Ee][-+]?[0-9]+

%%
"#".*   /* Single-line comment */

[0-9]+|[0-9]+"."[0-9]*{EXPO}?|"."?[0-9]+{EXPO}? {
    yylval.dValue = atof(yytext);
    return NUMBER;
}

\"[^"\n]*["\n] {
    yylval.sValue = strdup(yytext+1);
    if (yylval.sValue[yyleng-2] != '"')
        yyerror("improperly terminated string");
    else {
        yylval.sValue[yyleng-2] = 0;
        return STRING;
    }
}

[-()<>=+*/%^,;:{}] {
    return *yytext;
}

":="    return ASSIGN;
">="    return GE;
"<="    return LE;
"!="    return NE;
"if"    return IF;
"else"  return ELSE;
"then"  return THEN;
"and"   return AND;
"or"    return OR;
"not"   return NOT;

"print" return PRINT;
"scan"  return SCAN;
"exit"  return EXIT;

"PI"    return PI;
"abs"       return ABS;

{ID} {
    yylval.vName = strdup(yytext);
    return VARIABLE;
}

[ \t]

\n { ++lineno; }

. {
    yyerror("Unknown character");
    exit(1);
}
%%

int yywrap(void) {
    return 1;
}

void yyerror(char *s) {
    fprintf(stdout, "line %d: %s\n", lineno, s);
}