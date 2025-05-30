%{
#define LIST     strcat(buf, yytext)

int tokenFlag = false;

#define token(t) {LIST;  if(tokenFlag) printf("<%s>\n", t);}
#define tokenInteger(t, i) {LIST;  if(tokenFlag) printf("<%s: %d>\n", t, i);} 
#define tokenString(t, s) {LIST;  if(tokenFlag) printf("<%s: %s>\n", t, s);} 
#define MAX_LINE_LENG 256

#include <stdio.h>
#include <stdlib.h>
#include "y.tab.hpp"

int linenum = 1;
char buf[MAX_LINE_LENG];
%}


digits [0-9]+
integer  {digits}
plain_real {integer}"."{digits}?|"."{digits}
exp_real   ({integer}|{plain_real})[Ee]{digits}
real ({plain_real}|{exp_real})
identifier [A-Za-z_][A-Za-z0-9_]*
str \"([^\"]|\"\")*\"
newline \n
whitespace [ \t]+

%x COMMENT

%%
"."      {token("'.'"); return '.';}
","      {token("','"); return ',';}
":"      {token("':'"); return ':';}
";"      {token("';'"); return ';';}
"("      {token("'('"); return '(';} 
")"      {token("')'"); return ')';}
"["      {token("'['"); return '[';}
"]"      {token("']'"); return ']';}
"{"      {token("'{'"); return '{';}
"}"      {token("'}'"); return '}';}
".."     {token("'..'"); return RANGE_OP;}


"extern"   {token("EXTERN"); return EXTERN;}
"const"    {token("CONST"); return CONST;}   
"void"     {token("VOID"); return VOID_TYPE;}
"char"     {token("CHAR"); return CHAR_TYPE;}   
"string"   {token("STRING"); return STRING_TYPE;}
"bool"     {token("BOOL"); return BOOL_TYPE;}    
"int"      {token("INT"); return INT_TYPE;}
"float"    {token("FLOAT"); return FLOAT_TYPE;}
"double"   {token("DOUBLE"); return DOUBLE_TYPE;}  

"true"     {token("TRUE"); return TRUE;}
"false"    {token("FALSE"); return FALSE;}

"if"       {token("IF"); return IF;}
"else"     {token("ELSE"); return ELSE;} 
"switch"   {token("SWITCH"); return SWITCH;}
"case"     {token("CASE"); return CASE;}     
"default"  {token("DEFAULT"); return DEFAULT;}    

"do"       {token("DO"); return DO;}   
"while"    {token("WHILE"); return WHILE;}  
"for"      {token("FOR"); return FOR;}
"foreach"  {token("FOREACH"); return FOREACH;}
"break"    {token("BREAK"); return BREAK;}   
"continue" {token("CONTINUE"); return CONTINUE;}
"return"   {token("RETURN"); return RETURN;}

"print"    {token("PRINT"); return PRINT;}
"println"  {token("PRINTLN"); return PRINTLN;}
"read"     {token("READ"); return READ;}



"+"   {token("+"); return '+';} 
"-"   {token("-"); return '-';} 
"*"   {token("*"); return '*';} 
"/"   {token("/"); return '/';} 
"%"   {token("%"); return '%';} 
"="   {token("="); return '=';} 
"<"   {token("<"); return '<';} 
">"   {token(">"); return '>';} 
"!"   {token("!"); return '!';}  
"++"  {token("++"); return INC;} 
"--"  {token("--"); return DEC;} 
"<="  {token("<="); return LE;} 
">="  {token(">="); return GE;} 
"=="  {token("=="); return EQ;} 
"!="  {token("!="); return NEQ;} 
"&&"  {token("&&"); return LOGICAL_AND;} 
"||"  {token("||"); return LOGICAL_OR;} 



{identifier} {
    tokenString("ID", yytext); 
    yylval.strVal = (char*)malloc(strlen(yytext) + 1);
    strcpy(yylval.strVal, yytext);
    return ID;
}

{integer} {
    tokenInteger("integer", atoi(yytext));
    yylval.intVal = atoi(yytext);
    return INT_VAL;
}

{real} {
    tokenString("real", yytext);
    yylval.doubleVal = atof(yytext);
    return FLOAT_VAL; 
}

{str} {
    int len = strlen(yytext), i = 1, j = 0;
    char* tmp = (char*)malloc((len + 1) * sizeof(char));
    while(i < len - 1){
        if(yytext[i] == '\"'){
            if(yytext[i + 1] == '\"'){
                tmp[j] = '\"';
                j++;
                i += 2;
                continue;
            }
            else{
                i++;
                continue;
            }
        }
        tmp[j] = yytext[i];
        i++;
        j++;
    }
    tmp[j] = '\0';
    tokenString("string", tmp);
    yylval.strVal = tmp; // point to the processed string 
    return STR_VAL;
}

{whitespace} {
    LIST;
}


{newline} {
    LIST;
    linenum++;
    // printf("%d: %s", linenum, buf);
    buf[0] = '\0';
}

"//"[^\n]* {
    LIST;
}

"/*" {
    LIST; 
    BEGIN COMMENT;
}
<COMMENT>. {
    LIST;
}
<COMMENT>{newline} {
    LIST;
    linenum++;
    // printf("%d: %s", linenum, buf);
    buf[0] = '\0';
}
<COMMENT>"*/" {
    LIST; 
    BEGIN INITIAL;
}


. {
    LIST;
    printf("bad character: %s\n", yytext);
    exit(-1);
}
%%


int yywrap(){
    linenum++;
    // printf("%d: %s\n", linenum, buf);
    return 1;
}

