%{
#define LIST     strcat(buf, yytext)
#define token(t) {LIST; printf("<%s>\n", t);}
#define tokenInteger(t, i) {LIST; printf("<%s: %d>\n", t, i);} 
#define tokenString(t, s) {LIST; printf("<%s: %s>\n", t, s);}   
#define MAX_LINE_LENG 256
#define NIL -1

#include <iostream>
#include <unordered_map>
#include <vector>

using namespace std;


class SymbolTable{
private:
    int idx;
    unordered_map<string, int> symbol2idx;
    vector<string> symbols;

public:
    SymbolTable(){
        this->idx = 0;
    }

    int lookup(string s){
        if(symbol2idx.find(s) == symbol2idx.end()) return NIL;
        return symbol2idx[s];
    }

    int insert(string s){
        if(symbol2idx.find(s) != symbol2idx.end()) return symbol2idx[s];
        symbols.push_back(s);
        symbol2idx[s] = this->idx;
        this->idx++;
        return this->idx - 1;
    }

    void dump(){
        for(int i=0; i<this->idx; i++){
            cout << symbols[i] << endl;
        }
    }
};

SymbolTable* create(){
    return new SymbolTable();
}

int linenum = 1;
char buf[MAX_LINE_LENG];
SymbolTable* sbt = nullptr;
%}


sign   [+-]? 
digits [0-9]+
integer  {sign}{digits}
plain_real {integer}"."{digits}?|{sign}?"."{digits}
exp_real   ({integer}|{plain_real})[Ee]{sign}{digits}
real ({plain_real}|{exp_real})
identifier [A-Za-z][A-Za-z0-9]*
str \"([^\"]|\"\")*\"

newline \n
whitespace [ \t]+

%x COMMENT

%%
"."      {token("'.'");}
","      {token("','");}
":"      {token("':'");}
";"      {token("';'");}
"("      {token("'('");} 
")"      {token("')'");}
"["      {token("'['");}
"]"      {token("']'");}
"{"      {token("'{'");}
"}"      {token("'}'");}
   
"bool"     {token("BOOL");}      
"break"    {token("BREAK");}      
"case"     {token("CASE");}     
"char"     {token("CHAR");}      
"const"    {token("CONST");}      
"continue" {token("CONTINUE");}    
"default"  {token("DEFAULT");}    
"do"       {token("DO");}   
"double"   {token("DOUBLE");}  
"else"     {token("ELSE");} 
"extern"   {token("EXTERN");}
"false"    {token("FALSE");}
"float"    {token("FLOAT");}
"for"      {token("FOR");}
"foreach"  {token("FOREACH");}
"if"       {token("IF");}
"int"      {token("INT");}
"print"    {token("PRINT");}
"println"  {token("PRINTLN");}
"read"     {token("READ");}
"return"   {token("RETURN");}
"string"   {token("STRING");}
"switch"   {token("SWITCH");}
"true"     {token("TRUE");}
"void"     {token("VOID");}
"while"    {token("WHILE");}  

"+"      {token(yytext);} 
"++"     {token(yytext);} 
"-"     {token(yytext);} 
"--"     {token(yytext);} 
"*"      {token(yytext);} 
"/"     {token(yytext);} 
"%"      {token(yytext);} 
"="      {token(yytext);} 
"<"     {token(yytext);} 
"<="    {token(yytext);} 
">="    {token(yytext);} 
">"     {token(yytext);} 
"=="    {token(yytext);} 
"!="     {token(yytext);} 
"&&"    {token(yytext);} 
"||"    {token(yytext);} 
"!"      {token(yytext);}  


{identifier} {
    tokenString("ID", yytext); 
    sbt->insert(yytext);
}

{integer} {
    tokenInteger("integer", atoi(yytext));
}

{real} {
    tokenString("real", yytext);
}

{str} {
    int len = strlen(yytext), i = 0, j = 0;
    char* tmp = (char*)malloc((len + 1) * sizeof(char));
    while(i < len){
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
    free(tmp);
}

{whitespace} {
    LIST;
}


{newline} {
    LIST;
    printf("%d: %s", linenum++, buf);
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
    printf("%d: %s", linenum++, buf);
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


<<EOF>> {
    // if(YY_START == COMMENT){
    //     printf("error: Comment not closed.\n");
    //     exit(-1);
    // }
    printf("%d: %s\n", linenum++, buf);
    return 0;
}

%%



int main() {
    sbt = create();
    yylex(); 
    cout << endl << "Symbol Table:" << endl;
    sbt->dump();
    cout << endl;
    return 0;
}
