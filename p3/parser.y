%{
#include <cstdio>
#include <cstdlib>
#include <fstream>
#include "SymbolTable.hpp"
#include "AST.hpp"
#include "CodeGenerator.hpp"
#include "lex.yy.cpp"
#include <string>
#include <vector>
#include <iostream> 
#include <algorithm>
#include <string>

// extern
extern FILE* yyin;
extern int yylex();
extern int linenum;

using namespace std;

// trace 
bool traceFlag = false;
#define Trace(t) if(traceFlag) std::cout << t << std::endl;


// scope and symbol table
SymbolTable* sbt = nullptr; // global symbol table pointer
bool printSbt = false;
void enterScope();
void exitScope();

// code generator
CodeGenerator* codegen = nullptr;

// yyerror
void yyerror(string s);

bool printJasm = false;
%}

%union {
    int    intVal;
    char*  strVal;
    double doubleVal;
    DataType dataType;
    AstNode* node;
    vector<AstNode*>* nodeList;
    vector<int>* intList;
}

/* precedence */
%right '='
%left LOGICAL_OR
%left LOGICAL_AND
%right '!'
%left '<' LE '>' GE EQ NEQ
%left '+' '-'
%left '*' '/' '%'
%nonassoc LOWER_THAN_ELSE
%nonassoc ELSE
%nonassoc UPLUS UMINUS
%nonassoc PREFIX_INC PREFIX_DEC
%nonassoc POSTFIX_INC POSTFIX_DEC

/* tokens */
%token <intVal> INT_VAL
%token <strVal> STR_VAL
%token <doubleVal> FLOAT_VAL

%token <strVal> ID
%token RANGE_OP  
%token TRUE FALSE
%token EXTERN CONST VOID_TYPE CHAR_TYPE STRING_TYPE BOOL_TYPE INT_TYPE FLOAT_TYPE DOUBLE_TYPE
%token IF ELSE SWITCH CASE DEFAULT
%token DO WHILE FOR FOREACH CONTINUE BREAK RETURN
%token READ PRINT PRINTLN
%token INC DEC LE GE EQ NEQ LOGICAL_AND LOGICAL_OR

%type <dataType> data_type 
%type <node> expr literal numeric
%type <node> array_reference
%type <intList> array_dim_decl array_dim_reference 
%type <node> identifier_decl
%type <nodeList> identifier_list 
%type <node> arg
%type <nodeList> arg_list optional_arg_list
%type <node> param 
%type <nodeList> param_list optional_param_list
%type <node> stmt scoped_stmt block_stmt return_stmt simple_stmt condition_stmt loop_stmt simple_stmt_without_semicolon
%type <nodeList> stmt_list
%%

/* program: consists of a list of declarations */
program:
    decl_list { 
        Trace("Reduce: <decl_list> => <program>"); 
        codegen->generateProgram();
    }
;


/* declaration list: can be empty or consists of multiple declaration */
decl_list:
      /* empty */   
    | decl_list decl  { Trace("Reduce: <decl_list> <decl> => <decl_list>"); }
; 


/* declaration: a single declaration, can be be a constant, variable, or function declaration */
decl:
      /* empty */ ';' 
    | constant_decl   { Trace("Reduce: <constant_decl> => <decl>"); }
    | variable_decl   { Trace("Reduce: <variable_decl> => <decl>"); }
    | function_decl   { Trace("Reduce: <function_decl> => <decl>"); }
;


/* 
 * constant_decl: 
 * constant declartion, must begin with const keyword,  
 * and each identifer need to be initialized when declared
*/
constant_decl:
    CONST data_type identifier_list ';' {
        Trace("Reduce: <CONST> <data_type> <identifier_list> <';'> => <constant_decl>");
        if($2 == DataType::VOID_T) yyerror("void type is not allowed");
        for(AstNode* node : *$3){
            if(!node->isInit) yyerror("constant not initialize");
            if($2 != node->dataType) yyerror("datatype of expr is wrong");
            if(!node->isConst) yyerror("not constant expression");

            node->dataType = $2;
            node->isConst = true;  // constant variable is const

            // check existence
            bool success = sbt->insert(node); 
            if(!success) yyerror("redefinition of " + node->name);
        }
        codegen->insertEmpty();
    }
;

/* 
 * variable_decl: 
 * variable declaration. Identifier initialization is optional
 * array declarations are also included in this grammar
 */
variable_decl:
    data_type identifier_list ';' {
        Trace("Reduce: <data_type> <identifier_list> <';'> => <variable_decl>");
        if($1 == DataType::VOID_T) yyerror("void type is not allowed");
        codegen->insertEmpty();
        for(AstNode* node : *$2){
            if(node->dataType != DataType::UNKNOWN){
                if($1 != node->dataType) yyerror("datatype of expr is wrong");
            } 
            node->dataType = $1;
            node->isConst = false; // variable is not const
            node->isGlobal = sbt->isGlobal;
            // check existence
            bool success = sbt->insert(node);
            if(!success) yyerror("redefinition of " + node->name);
            codegen->generateVarDecl(node);
            codegen->combineTopTwo();
        }
    }
;

/* array_dim_decl: handles array dimension declarations */
array_dim_decl:
      array_dim_decl '[' INT_VAL']'  { $1->push_back($3); $$ = $1; }
    | '[' INT_VAL ']'  { $$ = new vector<int>(); $$->push_back($2); }
;

/* identifier list: contain one or more identifier declaration */
identifier_list:
      identifier_list ',' identifier_decl   {   
                                                Trace("Reduce: <identifier_list> <','> <identifier_decl> => <identifier_list>");
                                                $1->push_back($3);
                                                $$ = $1;
                                            }
    | identifier_decl                       {
                                                Trace("Reduce: <identifier_list> => <identifier_list>");
                                                $$ = new vector<AstNode*>();
                                                $$->push_back($1);
                                            }
;

/* identifier declaration: can be identifier, identifier with initial value or array declaration */
identifier_decl:
      ID '=' expr       {   
                            Trace("Reduce: <ID> <'='> <expr> => <identifier_decl>");
                            $$ = makeNode($3);
                            $$->name = $1;
                            $$->isInit = true;
                            $$->children = {$3};
                        }

    | ID                { 
                            Trace("Reduce: <ID> => <identifier_decl>");
                            $$ = makeNode();
                            $$->name = $1;
                            $$->isInit = false;
                        }

    | ID array_dim_decl {
                            Trace("Reduce: <ID> <array_dim_decl> => <identifier_decl>");
                            $$ = makeNode();
                            $$->name = $1;
                            $$->isArray = true;
                            for(int& dim : *$2){
                                if(dim < 1) yyerror("dimension < 1");
                                $$->arrayDims.push_back(dim);
                            }
                        }
;



/* 
 * function_decl: 
 * A function consists of a return type, a ID,
 * an optional parameter list, and a block of statements as the function body
 */


function_decl:
    // void function
    ID '(' optional_param_list ')' {
        Trace("Reduce: <ID> <'('> <optional_param_list> ) <')'> <block_stmt> => <function_decl>");

        // insert function identifier to symbol table
        AstNode* entry = makeNode();
        entry->isFunc = true;
        entry->dataType = DataType::VOID_T;
        entry->name = $1;
        entry->paramList = *$3; // link paramList to function identifier

        bool success = sbt->insert(entry);
        if(!success) yyerror("redefinition of " + entry->name);

        // enter scope
        enterScope();
        for(AstNode* param : *$3){
            bool success = sbt->insert(param);
            if(!success) yyerror("redefinition of " + param->name);
        }
    }
    block_stmt {
        if($6->dataType == DataType::UNKNOWN) $6->dataType = DataType::VOID_T;
        if(DataType::VOID_T != $6->dataType) yyerror("Wrong return type, " + getTypeStr(DataType::VOID_T) + " and " + getTypeStr($6->dataType));
        codegen->generateFuncDecl(sbt->lookup($1));
        // exit scope
        exitScope();
    }
    
    | data_type ID '(' optional_param_list ')' {
        Trace("Reduce: <data_type> <ID> <'('> <optional_param_list> ) <')'> <block_stmt> => <function_decl>");

        // insert function identifier to symbol table
        AstNode* entry = makeNode();
        entry->isFunc = true;
        entry->dataType = $1;
        entry->name = $2;
        entry->paramList = *$4; // link paramList to function identifier

        bool success = sbt->insert(entry);
        if(!success) yyerror("redefinition of " + entry->name);

        // enter scope
        enterScope();
        for(AstNode* param : *$4){
            bool success = sbt->insert(param);
            if(!success) yyerror("redefinition of " + param->name);
        }
    }
    block_stmt {
        if($7->dataType == DataType::UNKNOWN) $7->dataType = DataType::VOID_T;
        if($1 != $7->dataType) yyerror("Wrong return type, " + getTypeStr($1) + " and " + getTypeStr($7->dataType));
        codegen->generateFuncDecl(sbt->lookup($2));
        // exit scope
        exitScope();
    }
;


/* optional_param_list: handles the parameter list for a function declaration, may be empty */
optional_param_list:
      /* empty */   { Trace("Reduce: <empty> => <optional_param_list>");  $$ = new vector<AstNode*>(); }
    | param_list    { Trace("Reduce: <param_list> => <optional_param_list>");  $$ = $1; }
;

/* parameter list: contains one or more parameters */
param_list:
      param_list ',' param  { Trace("Reduce: <param_list> <,> <param> => <param_list>"); $1->push_back($3); $$ = $1; }
    | param   { Trace("Reduce: <param> => <param_list>"); $$ = new vector<AstNode*>(); $$->push_back($1); }             
;

/* parameter: single parameter, can be scalar type or structured type */
param:
      data_type ID  {
                        Trace("Reduce: <data_type> <ID> => <param>");
                        $$ = makeNode(); $$->dataType = $1; $$->name = $2; 
                    }
    // can be multi-dimension
    | data_type ID array_dim_decl {
        Trace("Reduce: <data_type> <ID> <array_dim_decl> => <param>");
        $$ = makeNode();
        $$->isArray = true;
        $$->dataType = $1;
        $$->name = $2;
        for(int& dim :*$3){
            if(dim < 1) yyerror("dimension < 1");
            $$->arrayDims.push_back(dim);
        }
    }
;



/* statement list: consists of zero of more statement*/
stmt_list:
      /* empty */    { Trace("Reduce: <empty> => <stmt_list>"); $$ = new vector<AstNode*>(); codegen->insertEmpty(); }
    | stmt_list stmt {
        Trace("Reduce: <stmt_list> <stmt> => <stmt_list>");
        $1->push_back($2);
        $$ = $1;
        codegen->combineTopTwo(); // if($$->size() >= 1)
    }
;


/* statement: can be statement or constant, variable declaration */
stmt:
      enter_scope block_stmt exit_scope { Trace("Reduce: <block_stmt> => <stmt>"); $$ = $2; }
    | simple_stmt       { Trace("Reduce: <simple_stmt> => <stmt>"); $$ = $1; }
    | condition_stmt    { Trace("Reduce: <condition_stmt> => <stmt>"); $$ = $1; }
    | loop_stmt         { Trace("Reduce: <loop_stmt> => <stmt>"); $$ = $1; }
    | return_stmt       { Trace("Reduce: <return_stmt> => <stmt>"); $$ = $1; }
    | constant_decl     { Trace("Reduce: <constant_decl> => <stmt>"); $$ = makeNode(); $$->dataType = DataType::UNKNOWN; }
    | variable_decl     { Trace("Reduce: <variable_decl> => <stmt>"); $$ = makeNode(); $$->dataType = DataType::UNKNOWN; }
;


/* scoped statement: for if-else and loop stmt, can be statement or constant, variable declaration */
scoped_stmt:
      block_stmt        { Trace("Reduce: <block_stmt> => <stmt>"); $$ = $1; }
    | simple_stmt       { Trace("Reduce: <simple_stmt> => <stmt>"); $$ = $1; }
    | condition_stmt    { Trace("Reduce: <condition_stmt> => <stmt>"); $$ = $1; }
    | loop_stmt         { Trace("Reduce: <loop_stmt> => <stmt>"); $$ = $1; }
    | return_stmt       { Trace("Reduce: <return_stmt> => <stmt>"); $$ = $1; }
    | constant_decl     { Trace("Reduce: <constant_decl> => <stmt>"); $$ = makeNode(); $$->dataType = DataType::UNKNOWN; }
    | variable_decl     { Trace("Reduce: <variable_decl> => <stmt>"); $$ = makeNode(); $$->dataType = DataType::UNKNOWN; }
;


/* block statement: uses '{' and '}' to group multiple statements together */
block_stmt:
      '{' stmt_list  '}' {
            
            Trace("Reduce: <'{'> <stmt_list> <'}'> => <block_stmt>");
            // all statements must have the same return type, excluding unknown return type
            DataType returnType = DataType::UNKNOWN;
            for(AstNode* node : *$2){
                if(node->dataType == DataType::UNKNOWN) continue;
                if(returnType == DataType::UNKNOWN) returnType = node->dataType;
                if(returnType != node->dataType) yyerror("Too many return type" + getTypeStr(returnType));
            }
            
            $$ = makeNode();
            $$->dataType = returnType;  
      }
;


/* simple statement: basic statement that will not return */
simple_stmt:
      /* empty */ ';'                   { Trace("Reduce: <empty> <';'> => <simple_stmt>"); $$ = makeNode(); $$->dataType = DataType::UNKNOWN; codegen->insertEmpty();}
    |  expr ';'                         { Trace("Reduce: <expr> <';'> => <simple_stmt>"); $$ = makeNode(); $$->dataType = DataType::UNKNOWN; codegen->generateNoLhsExpr($1);}
    | ID '=' expr ';'                   { 
                                            Trace("Reduce: <ID> <'='> <expr> <';'> => <simple_stmt>"); 
                                            AstNode* entry = sbt->lookup($1);
                                            if(entry == nullptr) yyerror(string("Identifier ") + $1 + " is not declared");
                                            if(entry->isConst) yyerror(string("Identifier ") + $1 + " is constant variable");
                                            if(entry->dataType != $3->dataType) yyerror("type not match");
                                            if($3->dataType == DataType::VOID_T) yyerror("data type of right value is void");
                                            if(entry->isFunc) yyerror("function can not be assinged");
                                            if($3->isFunc) yyerror("cannot assign function");
                                            if(entry->isArray != $3->isArray) yyerror("one is array and the other is not");
                                            if(entry->isArray){
                                                vector<int> left = entry->arrayDims;
                                                vector<int> right = $3->arrayDims;
                                                if(left.size() != right.size()) yyerror("dimension not match");
                                                if(left != right) yyerror("size of some dimension not match");
                                            }
                                            $$ = makeNode(); 
                                            $$->children = {entry, $3};
                                            $$->dataType = DataType::UNKNOWN; 
                                            codegen->generateAssignment($$);
                                        }
    | array_reference '=' expr ';'      { 
                                            Trace("Reduce: <array_reference> <'='> <expr> <';'> => <simple_stmt>"); 
                                            if($1->dataType != $3->dataType) yyerror("type not match");
                                            if($3->dataType == DataType::VOID_T) yyerror("data type of right value is void");
                                            if($3->isFunc) yyerror("cannot assign function");
                                            if($1->isArray != $3->isArray) yyerror("one is array and the other is not");
                                            if($1->isArray){
                                                vector<int> left = $1->arrayDims;
                                                vector<int> right = $3->arrayDims;
                                                if(left.size() != right.size()) yyerror("dimension not match");
                                                if(left != right) yyerror("size of some dimension not match");
                                            }                                        
                                            $$ = makeNode();
                                            $$->dataType = DataType::UNKNOWN; 
                                        } 

    | PRINT expr ';'                    { 
                                            Trace("Reduce: <PRINT> <expr> <';'> => <simple_stmt>"); 
                                            if($2->dataType == DataType::VOID_T) yyerror("datatype of expr is void"); 
                                            $$ = makeNode(); 
                                            $$->dataType = DataType::UNKNOWN; 
                                            codegen->generatePrint($2);
                                        }                
    | PRINTLN expr ';'                  { 
                                            Trace("Reduce: <PRINTLN> <expr> <';'> => <simple_stmt>"); 
                                            if($2->dataType == DataType::VOID_T) yyerror("datatype of expr is void"); 
                                            $$ = makeNode(); 
                                            $$->dataType = DataType::UNKNOWN; 
                                            codegen->generatePrintln($2);
                                        }            
    | READ ID ';'                       { 
                                            Trace("Reduce: <READ> <ID> <';'> => <simple_stmt>"); 
                                            AstNode* entry = sbt->lookup($2);
                                            if(entry == nullptr) yyerror(string("ID ") + $2 + " is not declared");
                                            if(entry->isArray) yyerror("identifier " + entry->name + " is array");
                                            if(entry->isFunc) yyerror("identifier " + entry->name + " is function");
                                            if(entry->isConst) yyerror("identifier " + entry->name + " is constant variable");
                                            $$ = makeNode(); $$->dataType = DataType::UNKNOWN; 
                                        } 
    | READ array_reference ';'          { 
                                            Trace("Reduce: <READ> <array_reference> <';'> => <simple_stmt>"); 
                                            $$ = makeNode(); $$->dataType = DataType::UNKNOWN; 
                                        }                                                    
;

/* simple statement witout semicolon: same as simple statement but has no semicolon */
simple_stmt_without_semicolon:
      /* empty */                       { Trace("Reduce: <empty> => <simple_stmt_without_semicolon>"); $$ = makeNode(); $$->dataType = DataType::UNKNOWN; }
    | expr                              { Trace("Reduce: <expr> => <simple_stmt_without_semicolon>"); $$ = makeNode(); $$->dataType = DataType::UNKNOWN; codegen->generateNoLhsExpr($1);}
    | ID '=' expr                       { 
                                            Trace("Reduce: <ID> <'='> <expr> => <simple_stmt_without_semicolon>"); 
                                            AstNode* entry = sbt->lookup($1);
                                            if(entry == nullptr) yyerror(string("Identifier ") + $1 + " is not declared");
                                            if(entry->isConst) yyerror(string("Identifier ") + $1 + " is constant variable");
                                            if(entry->dataType != $3->dataType) yyerror("type not match");
                                            if($3->dataType == DataType::VOID_T) yyerror("data type of right value is void");
                                            if(entry->isFunc) yyerror("function can not be assinged");
                                            if($3->isFunc) yyerror("cannot assign function");
                                            if(entry->isArray != $3->isArray) yyerror("one is array and the other is not");
                                            if(entry->isArray){
                                                vector<int> left = entry->arrayDims;
                                                vector<int> right = $3->arrayDims;
                                                if(left.size() != right.size()) yyerror("dimension not match");
                                                if(left != right) yyerror("size of some dimension not match");
                                            }
                                            $$ = makeNode(); 
                                            $$->children = {entry, $3};
                                            $$->dataType = DataType::UNKNOWN; 
                                            codegen->generateAssignment($$);
                                        }
    | array_reference '=' expr          { 
                                            Trace("Reduce: <array_reference> <'='> <expr> => <simple_stmt_without_semicolon>"); 
                                            if($1->dataType != $3->dataType) yyerror("type not match");
                                            if($3->dataType == DataType::VOID_T) yyerror("data type of right value is void");
                                            if($3->isFunc) yyerror("cannot assign function");
                                            if($1->isArray != $3->isArray) yyerror("one is array and the other is not");
                                            if($1->isArray){
                                                cout << "arr_ref = expr;" << endl;
                                                vector<int> left = $1->arrayDims;
                                                vector<int> right = $3->arrayDims;
                                                if(left.size() != right.size()) yyerror("dimension not match");
                                                if(left != right) yyerror("size of some dimension not match");
                                            }                                        
                                            $$ = makeNode();
                                            $$->dataType = DataType::UNKNOWN; 
                                        } 

    | PRINT expr                        { 
                                            Trace("Reduce: <PRINT> <expr> => <simple_stmt_without_semicolon>"); 
                                            if($2->dataType == DataType::VOID_T) yyerror("datatype of expr is void"); 
                                            $$ = makeNode(); 
                                            $$->dataType = DataType::UNKNOWN; 
                                            codegen->generatePrint($2);

                                        }                
    | PRINTLN expr                      { 
                                            Trace("Reduce: <PRINTLN> <expr> => <simple_stmt_without_semicolon>"); 
                                            if($2->dataType == DataType::VOID_T) yyerror("datatype of expr is void"); 
                                            $$ = makeNode(); 
                                            $$->dataType = DataType::UNKNOWN; 
                                            codegen->generatePrintln($2);
                                        }            
    | READ ID                           { 
                                            Trace("Reduce: <READ> <ID> => <simple_stmt_without_semicolon>"); 
                                            AstNode* entry = sbt->lookup($2);
                                            if(entry == nullptr) yyerror(string("ID ") + $2 + " is not declared");
                                            if(entry->isArray) yyerror("identifier " + entry->name + " is array");
                                            if(entry->isFunc) yyerror("identifier " + entry->name + " is function");
                                            if(entry->isConst) yyerror("identifier " + entry->name + " is constant variable");
                                            $$ = makeNode(); $$->dataType = DataType::UNKNOWN; 
                                        } 
    | READ array_reference              { 
                                            Trace("Reduce: <READ> <array_reference> => <simple_stmt_without_semicolon>"); 
                                            $$ = makeNode(); $$->dataType = DataType::UNKNOWN; 
                                        }                                                        
;


/* 
 * condition statement:  
 * if/if-else statement, expression in expr must be boolean expression,
 * return of if and else cannot be different
*/
condition_stmt:
      IF '(' expr ')' enter_scope scoped_stmt exit_scope %prec LOWER_THAN_ELSE   {
            Trace("Reduce: <IF> <'('> <expr> <')'> <stmt> => <condition_stmt>"); 
            if($3->dataType != DataType::BOOL_T) yyerror("not boolean expression");
            $$ = makeNode($6); // return type of statement
            codegen->generateIf($3);
        }
    | IF '(' expr ')' enter_scope scoped_stmt exit_scope ELSE enter_scope scoped_stmt exit_scope {
        Trace("Reduce: <IF> <'('> <expr> <')'> <stmt> <ELSE> <stmt> => <condition_stmt>"); 
        if($3->dataType != DataType::BOOL_T) yyerror("not boolean expression");
        // return type of statement
        if($6->dataType == $10->dataType) $$ = makeNode($6);
        else if($6->dataType == DataType::UNKNOWN) $$ = makeNode($10);
        else if($10->dataType == DataType::UNKNOWN) $$ = makeNode($6);
        else yyerror("more than one return type");
        codegen->generateIfElse($3);
    }            
;

/* loop statement: */
loop_stmt:
      WHILE '(' expr ')' enter_scope scoped_stmt exit_scope {
            Trace("Reduce: <WHILE> <'('> <expr> <')'> <simple_or_block_stmt> => <loop_stmt>"); 
            Trace("Reduce: <while_stmt> => <loop_stmt>"); 
            if($3->dataType != DataType::BOOL_T) yyerror("not boolean expression");
            $$ = makeNode($6); // return type of statement
            codegen->generateWhile($3);
      }                       
    | FOR '(' simple_stmt_without_semicolon ';' expr ';' simple_stmt_without_semicolon ')' enter_scope scoped_stmt exit_scope {
        Trace("Reduce: <FOR> <'('> <simple_stmt_without_semicolon> <';'> <expr> <';'> <simple_stmt_without_semicolon> <')'> <simple_or_block_stmt> => <loop_stmt>"); 
        if($5->dataType != DataType::BOOL_T) yyerror("not boolean expression");
        $$ = makeNode($10); // return type of statement
        codegen->generateFor($5);
    }            
    | FOREACH '(' ID ':' numeric RANGE_OP numeric ')' enter_scope scoped_stmt exit_scope {
        Trace("Reduce: <FOREACH> <'('> <ID> <':'> <numeric> <RANGE_OP> <numeric> <)> <simple_or_block_stmt> => <loop_stmt>"); 
        AstNode* entry = sbt->lookup($3);
        if(entry == nullptr) yyerror(string("ID ") + $3 + " is not declared");
        if(entry->isArray) yyerror("identifier " + entry->name + " is array");
        if(entry->isFunc) yyerror("identifier " + entry->name + " is function");
        $$ = makeNode($10); // return type of statement
        AstNode* node = makeNode();
        entry->exprType = ExprType::EXPR_ID;
        node->children = {entry, $5, $7};
        codegen->generateForeach(node);
    }
;

/* numeric: number use in foreach statement, must be integer ID or integer constant val*/
numeric:
     ID  {
            Trace("Reduce: <ID> => <numeric>")
            AstNode* entry = sbt->lookup($1);
            if(entry == nullptr) yyerror(string("ID ") + $1 + " is not declared");
            if(entry->isArray) yyerror("identifier " + entry->name + " is array");
            if(entry->isFunc) yyerror("identifier " + entry->name + " is function");
            if(entry->dataType != DataType::INT_T) yyerror("not integer");
            $$ = makeNode(entry); 
            $$->exprType = ExprType::EXPR_ID;
            $$->name = entry->name;
            $$->number = entry->number;
            $$->isGlobal = entry->isGlobal;
     }     
    | INT_VAL  { Trace("Reduce: <INT_VAL: " + to_string($1) + "> => <numeric>"); $$ = makeNode(); $$->dataType = DataType::INT_T; $$->isConst = true; $$->iVal = $1; $$->exprType = ExprType::EXPR_LITERAL; }
    | '-' INT_VAL  { Trace("Reduce: <INT_VAL: " + to_string($2) + "> => <numeric>"); $$ = makeNode(); $$->dataType = DataType::INT_T; $$->isConst = true; $$->iVal = -$2; $$->exprType = ExprType::EXPR_LITERAL; }
    | '+' INT_VAL  { Trace("Reduce: <INT_VAL: " + to_string($2) + "> => <numeric>"); $$ = makeNode(); $$->dataType = DataType::INT_T; $$->isConst = true; $$->iVal = $2; $$->exprType = ExprType::EXPR_LITERAL; }
;


/* return statement: return a expression with known type or return nothing with void type*/
return_stmt:
      RETURN ';'       { Trace("Reduce: <return> <';'> => <return_stmt>"); $$ = makeNode(); $$->dataType = DataType::VOID_T; codegen->generateReturn($$); }
    | RETURN expr ';'  { Trace("Reduce: <return> <expr> <';'> => <return_stmt>"); $$ = makeNode($2); codegen->generateReturn($2);}       
;


/* 
 * expression: 
 * relational expression, arthimetic expression, function invocation,
 * increasement, decreasement, array reference, identifier, literal
 */
expr:
      expr LOGICAL_AND expr         { 
                                        Trace("Reduce: <expr> <LOGICAL_AND> <expr> => <expr>"); 
                                        if($1->isFunc || $3->isFunc) yyerror("function cannot use &&");
                                        if($1->isArray || $3->isArray) yyerror("array cannot use &&");
                                        if($1->dataType != $3->dataType) yyerror("type not match");
                                        if($1->dataType != DataType::BOOL_T) yyerror("not boolean type");
                                        $$ = makeNode();
                                        $$->iVal = $1->iVal && $3->iVal;
                                        $$->dataType = DataType::BOOL_T;
                                        $$->isConst = $1->isConst && $3->isConst;
                                        $$->exprType = ExprType::EXPR_LAND;
                                        $$->children = {$1, $3};
                                    } 
    | expr LOGICAL_OR expr          {   
                                        Trace("Reduce: <expr> <LOGICAL_OR> <expr> => <expr>"); 
                                        if($1->isFunc || $3->isFunc) yyerror("function cannot use ||");
                                        if($1->isArray || $3->isArray) yyerror("array cannot use ||");
                                        if($1->dataType != $3->dataType) yyerror("type not match");
                                        if($1->dataType != DataType::BOOL_T) yyerror("not boolean type");
                                        $$ = makeNode(); 
                                        $$->iVal = $1->iVal || $3->iVal;
                                        $$->dataType = DataType::BOOL_T;
                                        $$->isConst = $1->isConst && $3->isConst;
                                        $$->exprType = ExprType::EXPR_LOR;
                                        $$->children = {$1, $3};
                                    }    
    | '!' expr                      { 
                                        Trace("Reduce: <'!'> <expr> => expr"); 
                                        if($2->isFunc) yyerror("function cannot use !");
                                        if($2->isArray) yyerror("array cannot use !");
                                        if($2->dataType != DataType::BOOL_T) yyerror("not boolean type");
                                        $$ = makeNode();
                                        $$->iVal = !$2->iVal;
                                        $$->dataType = DataType::BOOL_T;
                                        $$->isConst = $2->isConst;
                                        $$->exprType = ExprType::EXPR_NOT;
                                        $$->children = {$2};
                                    }
    | expr '<' expr                 {
                                        Trace("Reduce: <expr> <'<'> <expr> => <expr>"); 
                                        if($1->isFunc || $3->isFunc) yyerror("function cannot use <");
                                        if($1->isArray || $3->isArray) yyerror("array cannot use <");
                                        if($1->dataType != $3->dataType) yyerror("type not match");
                                        if(!($1->dataType == DataType::INT_T || $1->dataType == DataType::FLOAT_T)){
                                            yyerror(getTypeStr($1->dataType) + " type cannot use <");
                                        }
                                        $$ = makeNode();
                                        $$->iVal = $1->iVal < $3->iVal;
                                        $$->dataType = DataType::BOOL_T;
                                        $$->isConst = $1->isConst && $3->isConst;
                                        $$->exprType = ExprType::EXPR_LT;
                                        $$->children = {$1, $3};
                                    } 
    | expr '>' expr                 {
                                        Trace("Reduce: <expr> <'>'> <expr> => <expr>"); 
                                        if($1->isFunc || $3->isFunc) yyerror("function cannot use >");
                                        if($1->isArray || $3->isArray) yyerror("array cannot use >");
                                        if($1->dataType != $3->dataType) yyerror("type not match");
                                        if(!($1->dataType == DataType::INT_T || $1->dataType == DataType::FLOAT_T)){
                                            yyerror(getTypeStr($1->dataType) + " type cannot use >");
                                        }
                                        $$ = makeNode();
                                        $$->iVal = $1->iVal > $3->iVal;
                                        $$->dataType = DataType::BOOL_T;
                                        $$->isConst = $1->isConst && $3->isConst;
                                        $$->exprType = ExprType::EXPR_GT;
                                        $$->children = {$1, $3};
                                    } 
    | expr LE  expr                 {
                                        Trace("Reduce: <expr> <LE> <expr> => <expr>"); 
                                        if($1->isFunc || $3->isFunc) yyerror("function cannot use <=");
                                        if($1->isArray || $3->isArray) yyerror("array cannot use <=");
                                        if($1->dataType != $3->dataType) yyerror("type not match");
                                        if(!($1->dataType == DataType::INT_T || $1->dataType == DataType::FLOAT_T)){
                                            yyerror(getTypeStr($1->dataType) + " type cannot use <=");
                                        }
                                        $$ = makeNode();
                                        $$->iVal = $1->iVal <= $3->iVal;
                                        $$->dataType = DataType::BOOL_T;
                                        $$->isConst = $1->isConst && $3->isConst;
                                        $$->exprType = ExprType::EXPR_LE;
                                        $$->children = {$1, $3};
                                    }  
    | expr GE  expr                 {
                                        Trace("Reduce: <expr> <GE> <expr> => <expr>"); 
                                        if($1->isFunc || $3->isFunc) yyerror("function cannot use >=");
                                        if($1->isArray || $3->isArray) yyerror("array cannot use >=");
                                        if($1->dataType != $3->dataType) yyerror("type not match");
                                        if(!($1->dataType == DataType::INT_T || $1->dataType == DataType::FLOAT_T)){
                                            yyerror(getTypeStr($1->dataType) + " type cannot use >=");
                                        }
                                        $$ = makeNode();
                                        $$->iVal = $1->iVal >= $3->iVal;
                                        $$->dataType = DataType::BOOL_T;
                                        $$->isConst = $1->isConst && $3->isConst;
                                        $$->exprType = ExprType::EXPR_GE;
                                        $$->children = {$1, $3};
                                    } 
    | expr EQ  expr                 {
                                        Trace("Reduce: <expr> <EQ> <expr> => <expr>"); 
                                        if($1->isFunc || $3->isFunc) yyerror("function cannot use ==");
                                        if($1->isArray != $3->isArray) yyerror("one is array and the other is not");
                                        if($1->dataType != $3->dataType) yyerror("type not match");
                                        if($1->isArray && $1->arrayDims.size() != $3->arrayDims.size()) yyerror("dimension not match");
                                        $$ = makeNode();
                                        $$->iVal = $1->iVal == $3->iVal;
                                        $$->dataType = DataType::BOOL_T;
                                        $$->isConst = $1->isConst && $3->isConst;
                                        $$->exprType = ExprType::EXPR_EQ;
                                        $$->children = {$1, $3};
                                    }  
    | expr NEQ expr                 {
                                        Trace("Reduce: <expr> <NEQ> <expr> => <expr>"); 
                                        if($1->isFunc || $3->isFunc) yyerror("function cannot use !=");
                                        if($1->isArray != $3->isArray) yyerror("one is an array and the other is not");
                                        if($1->dataType != $3->dataType) yyerror("type not match");
                                        if($1->isArray && $1->arrayDims.size() != $3->arrayDims.size()) yyerror("dimension not match");
                                        $$ = makeNode();
                                        $$->iVal = $1->iVal != $3->iVal;
                                        $$->dataType = DataType::BOOL_T;
                                        $$->isConst = $1->isConst && $3->isConst;
                                        $$->exprType = ExprType::EXPR_NEQ;
                                        $$->children = {$1, $3};
                                    }  
    | expr '+' expr                 {
                                        Trace("Reduce: <expr> <'+'> <expr> => <expr>"); 
                                        if($1->isFunc || $3->isFunc) yyerror("function cannot add");
                                        if($1->isArray || $3->isArray) yyerror("array cannot add");
                                        if($1->dataType != $3->dataType) yyerror("type not match");
                                        if(!($1->dataType == DataType::INT_T || $1->dataType == DataType::FLOAT_T || $1->dataType == DataType::STRING_T)){
                                            yyerror(getTypeStr($1->dataType) + " type cannot add");
                                        }
                                        $$ = makeNode(); 
                                        $$->iVal = $1->iVal + $3->iVal;
                                        $$->dataType = $1->dataType;
                                        $$->isConst = $1->isConst && $3->isConst;
                                        $$->exprType = ExprType::EXPR_ADD;
                                        $$->children = {$1, $3};
                                    }  
    | expr '-' expr                 {
                                        Trace("Reduce: <expr> <'-'> <expr> => <expr>"); 
                                        if($1->isFunc || $3->isFunc) yyerror("function cannot sub");
                                        if($1->isArray || $3->isArray) yyerror("array cannot sub");
                                        if($1->dataType != $3->dataType) yyerror("type not match");
                                        if(!($1->dataType == DataType::INT_T || $1->dataType == DataType::FLOAT_T)){
                                            yyerror(getTypeStr($1->dataType) + " type cannot sub");
                                        }
                                        $$ = makeNode(); 
                                        $$->iVal = $1->iVal - $3->iVal;
                                        $$->dataType = $1->dataType;
                                        $$->isConst = $1->isConst && $3->isConst;
                                        $$->exprType = ExprType::EXPR_SUB;
                                        $$->children = {$1, $3};
                                    } 
    | expr '*' expr                 {
                                        Trace("Reduce: <expr> <'*'> <expr> => <expr>"); 
                                        if($1->isFunc || $3->isFunc) yyerror("function cannot mul");
                                        if($1->isArray || $3->isArray) yyerror("array cannot mul");
                                        if($1->dataType != $3->dataType) yyerror("type not match");
                                        if(!($1->dataType == DataType::INT_T || $1->dataType == DataType::FLOAT_T)){
                                            yyerror(getTypeStr($1->dataType) + " type cannot mul");
                                        }
                                        $$ = makeNode(); 
                                        $$->iVal = $1->iVal * $3->iVal;
                                        $$->dataType = $1->dataType;
                                        $$->isConst = $1->isConst && $3->isConst;
                                        $$->exprType = ExprType::EXPR_MUL;
                                        $$->children = {$1, $3};
                                    }     
    | expr '/' expr                 {
                                        Trace("Reduce: <expr> <'/'> <expr> => <expr>"); 
                                        if($1->isFunc || $3->isFunc) yyerror("function cannot div");
                                        if($1->isArray || $3->isArray) yyerror("array cannot div");
                                        if($1->dataType != $3->dataType) yyerror("type not match");
                                        if(!($1->dataType == DataType::INT_T || $1->dataType == DataType::FLOAT_T)){
                                            yyerror(getTypeStr($1->dataType) + " type cannot div");
                                        }
                                        $$ = makeNode(); 
                                        $$->iVal = $1->iVal / $3->iVal;
                                        $$->dataType = $1->dataType;
                                        $$->isConst = $1->isConst && $3->isConst;
                                        $$->exprType = ExprType::EXPR_DIV;
                                        $$->children = {$1, $3};
                                    } 
    | expr '%' expr                 {
                                        Trace("Reduce: <expr> <'%'> <expr> => <expr>"); 
                                        if($1->isFunc || $3->isFunc) yyerror("function cannot mod");
                                        if($1->isArray || $3->isArray) yyerror("array cannot mod");
                                        if($1->dataType != $3->dataType) yyerror("type not match");
                                        if(!($1->dataType == DataType::INT_T)){
                                            yyerror(getTypeStr($1->dataType) + " type cannot mod");
                                        }
                                        $$ = makeNode(); 
                                        $$->iVal = $1->iVal % $3->iVal;
                                        $$->dataType = DataType::INT_T;
                                        $$->isConst = $1->isConst && $3->isConst;
                                        $$->exprType = ExprType::EXPR_MOD;
                                        $$->children = {$1, $3};
                                    } 
    | ID INC  %prec POSTFIX_INC   {
                                        Trace("Reduce: <INC> <expr> => <expr>"); 
                                        AstNode* entry = sbt->lookup($1);
                                        if(entry == nullptr) yyerror(string("ID ") + $1 + " is not declared");
                                        if(entry->isArray) yyerror("identifier " + entry->name + " is array");
                                        if(entry->isFunc) yyerror("identifier " + entry->name + " is function");
                                        if(entry->isConst) yyerror("identifier " + entry->name + " is constant variable");
                                        if(!(entry->dataType == DataType::INT_T || entry->dataType == DataType::FLOAT_T)){
                                            yyerror(getTypeStr(entry->dataType) + " type cannot INC");
                                        }
                                        $$ = makeNode(entry);
                                        $$->iVal = $$->iVal;
                                        $$->exprType = ExprType::EXPR_INC_POSTFIX;
                                        $$->name = entry->name;    
                                        $$->number = entry->number;       
                                        $$->isGlobal = entry->isGlobal; 
                                  }
    | ID DEC  %prec POSTFIX_DEC   {
                                        Trace("Reduce: <expr> <DEC> => <expr>"); 
                                        AstNode* entry = sbt->lookup($1);
                                        if(entry == nullptr) yyerror(string("ID ") + $1 + " is not declared");
                                        if(entry->isArray) yyerror("identifier " + entry->name + " is array");
                                        if(entry->isFunc) yyerror("identifier " + entry->name + " is function");
                                        if(entry->isConst) yyerror("identifier " + entry->name + " is constant variable");
                                        if(!(entry->dataType == DataType::INT_T || entry->dataType == DataType::FLOAT_T)){
                                            yyerror(getTypeStr(entry->dataType) + " type cannot DEC");
                                        }
                                        $$ = makeNode(entry);
                                        $$->iVal = $$->iVal;
                                        $$->exprType = ExprType::EXPR_DEC_POSTFIX;
                                        $$->name = entry->name;    
                                        $$->number = entry->number;   
                                        $$->isGlobal = entry->isGlobal;    
                                  }
    | INC ID  %prec PREFIX_INC    {
                                        Trace("Reduce: <INC> <expr> => <expr>"); 
                                        AstNode* entry = sbt->lookup($2);
                                        if(entry == nullptr) yyerror(string("ID ") + $2 + " is not declared");
                                        if(entry->isArray) yyerror("identifier " + entry->name + " is array");
                                        if(entry->isFunc) yyerror("identifier " + entry->name + " is function");
                                        if(entry->isConst) yyerror("identifier " + entry->name + " is constant variable");
                                        if(!(entry->dataType == DataType::INT_T || entry->dataType == DataType::FLOAT_T)){
                                            yyerror(getTypeStr(entry->dataType) + " type cannot INC");
                                        }
                                        $$ = makeNode(entry);
                                        $$->iVal = $$->iVal + 1;
                                        $$->exprType = ExprType::EXPR_INC_PREFIX;
                                        $$->name = entry->name;    
                                        $$->number = entry->number;       
                                        $$->isGlobal = entry->isGlobal;     
                                    }
    | DEC ID  %prec PREFIX_DEC    {
                                        Trace("Reduce: <DEC> <expr> => <expr>"); 
                                        AstNode* entry = sbt->lookup($2);
                                        if(entry == nullptr) yyerror(string("ID ") + $2 + " is not declared");
                                        if(entry->isArray) yyerror("identifier " + entry->name + " is array");
                                        if(entry->isFunc) yyerror("identifier " + entry->name + " is function");
                                        if(entry->isConst) yyerror("identifier " + entry->name + " is constant variable");
                                        if(!(entry->dataType == DataType::INT_T || entry->dataType == DataType::FLOAT_T)){
                                            yyerror(getTypeStr(entry->dataType) + " type cannot DEC");
                                        }
                                        $$ = makeNode(entry);
                                        $$->iVal = $$->iVal - 1;
                                        $$->exprType = ExprType::EXPR_DEC_PREFIX;
                                        $$->name = entry->name;    
                                        $$->number = entry->number;   
                                        $$->isGlobal = entry->isGlobal;       
                                    } 
    | '+' expr  %prec UPLUS         {
                                        Trace("Reduce: <'+'> <expr> => <expr>"); 
                                        if($2->isFunc) yyerror("function cannot be pos");
                                        if($2->isArray) yyerror("array cannot be pos");
                                        if(!($2->dataType == DataType::INT_T || $2->dataType == DataType::FLOAT_T)){
                                            yyerror(getTypeStr($2->dataType) + " type cannot be pos");
                                        }
                                        $$ = makeNode($2);
                                        $$->exprType = ExprType::EXPR_POS;
                                        $$->children = {$2};
                                    } 
    | '-' expr  %prec UMINUS        {
                                        Trace("Reduce: <'-'> <expr> => <expr>"); 
                                        if($2->isFunc) yyerror("function cannot be neg");
                                        if($2->isArray) yyerror("array cannot be neg");
                                        if(!($2->dataType == DataType::INT_T || $2->dataType == DataType::FLOAT_T)){
                                            yyerror(getTypeStr($2->dataType) + " type cannot be neg");
                                        }
                                        $$ = makeNode($2); 
                                        $$->iVal = -$$->iVal;
                                        $$->exprType = ExprType::EXPR_NEG;
                                        $$->children = {$2};
                                    }                  
    | '(' expr ')'                  { Trace("Reduce: <'('> <expr> <')'> => <expr>");  $$ = $2;}
    | ID '(' optional_arg_list ')'  {
                                        Trace("Reduce: <ID> <'('> <optional_arg_list> <')'> => <expr>"); 
                                        AstNode* fn = sbt->lookup($1);
                                        if(fn == nullptr) yyerror(string("Function ") + $1 + " is not declared");
                                        if(!fn->isFunc) yyerror(string("Identifier ") + $1 + " is not a fucntion");
                                        vector<AstNode*>* argList = $3;
                                        if(fn->paramList.size() != argList->size()) yyerror("arg count not match");
                            
                                        // check whether all args are valid
                                        int numArgs = fn->paramList.size();
                                        for(int i=0; i<numArgs; i++){
                                            AstNode* param = fn->paramList[i];
                                            AstNode* arg = (*argList)[i];
                                            if(arg->isFunc) yyerror("arg is function");
                                            if(!(param->dataType == arg->dataType && param->isArray == arg->isArray)){        
                                                yyerror("arg type not match");
                                            }
                                            if(param->isArray && arg->isArray){
                                                vector<int> pArrayDims = fn->paramList[i]->arrayDims;
                                                vector<int> aArrayDims = arg->arrayDims;                                                
                                                if(pArrayDims.size() != aArrayDims.size()) yyerror("arg dimension not match"); 
                                                if(pArrayDims != aArrayDims) yyerror("size of some dimension not match");
                                            }
                                        }
                                        $$ = makeNode();
                                        $$->dataType = fn->dataType;
                                        $$->name = fn->name;
                                        $$->children = *argList;
                                        $$->exprType = ExprType::EXPR_FUNCCALL;
                                    }
    | array_reference               { Trace("Reduce: <array_reference> => <expr>"); $$ = $1; }
    
    | ID                            {   
                                        Trace("Reduce: <ID> => <expr>"); 

                                        // constant, varibale or array, exclude function call
                                        AstNode* entry = sbt->lookup($1);
                                        if(entry == nullptr) yyerror(string("Identifier ") + $1 + " is not declared");
                                        
                                        // function cannot be an expr
                                        if(entry->isFunc) yyerror(string("Identifier ") + $1 + " is a function");
                                        
                                        $$ = makeNode(entry);
                                        $$->name = entry->name;
                                        $$->exprType = ExprType::EXPR_ID;
                                        $$->number = entry->number;
                                        $$->isGlobal = entry->isGlobal;
                                    } 
    | literal                       { Trace("Reduce: <literal> => <expr>"); $$ = $1; $$->exprType = ExprType::EXPR_LITERAL; }
;



/* array reference: array reference of declared array identifier, array slicing is allowed */
array_reference:
    ID array_dim_reference {
        Trace("Reduce: <ID> <array_dim_reference> => <array_reference>");

        vector<int>* arr = $2;
        AstNode* entry = sbt->lookup($1);
        if(entry == nullptr) yyerror(string("Identifier ") + $1 + " is not declared");
        if(!entry->isArray) yyerror(string("Identifier ") + $1 + " is not an array");

        if(entry->arrayDims.size() < arr->size()) yyerror("too many dimension of array reference");
        int numDims = arr->size();
        for(int i=0; i<numDims; i++){
            if((*arr)[i] < 0 || (*arr)[i] >= entry->arrayDims[i]) yyerror("index out of range");
        }

        $$ = makeNode();
        $$->dataType = entry->dataType;
        // array slicing, when not giving full dimension
        if(entry->arrayDims.size() != numDims){
            for(int i=numDims; i<entry->arrayDims.size(); i++){
                $$->arrayDims.push_back(entry->arrayDims[i]);
            }
            $$->isArray = true;
        }
    }
;


/* array dimension reference: handle the dimensions of an array identifier*/
array_dim_reference:
      '[' expr ']'                      { 
                                            Trace("Reduce: <'['> <expr> <']'> => <array_dim_reference>");
                                            if($2->dataType != DataType::INT_T) yyerror("not integer expression");
                                            if($2->isArray) yyerror("not integer expression");
                                            $$ = new vector<int>(); $$->push_back($2->iVal);                               
                                        } 
    | array_dim_reference '[' expr ']'  {
                                            Trace("Reduce: <array_dim_reference> <'['> <expr> <']'> => <array_dim_reference>");
                                            if($3->dataType != DataType::INT_T) yyerror("not integer expression");
                                            if($3->isArray) yyerror("not integer expression");
                                            $1->push_back($3->iVal); $$ = $1;
                                        }
;


/* optional arg list: handles the argument list for a function invocation, may be empty */
optional_arg_list:
      /* empty */  { Trace("Reduce: <empty> => <optional_arg_list>"); $$ = new vector<AstNode*>(); }
    | arg_list     { Trace("Reduce: <arg_list> => <optional_arg_list>"); $$ = $1; }
;

/* argument list: contains one or more arguments */
arg_list:
      arg_list ',' arg  { Trace("Reduce: <arg_list> <','> <arg> => <arg_list>"); $1->push_back($3); $$ = $1; }  
    | arg               { Trace("Reduce: <arg> => <arg_list>"); $$ = new vector<AstNode*>(); $$->push_back($1); }          
;

/* argument: single argument, can be an expression */
arg:
    expr     { Trace("Reduce: <expr> => <arg>"); $$ = $1; }
;

/* literal: constant value directly given by input program */
literal:
      TRUE             { Trace("Reduce: true => <literal>"); $$ = makeNode(); $$->dataType = DataType::BOOL_T;  $$->isConst = true; $$->iVal = 1; }
    | FALSE            { Trace("Reduce: false => <literal>") ;$$ = makeNode(); $$->dataType = DataType::BOOL_T; $$->isConst = true; $$->iVal = 0; }
    | INT_VAL          { Trace("Reduce: <INT_VAL: " + to_string($1) + "> => <literal>"); $$ = makeNode(); $$->dataType = DataType::INT_T;    $$->isConst = true; $$->iVal = $1; }
    | STR_VAL          { Trace("Reduce: <STR_VAL: " + string($1) + "> => <literal>"); $$ = makeNode(); $$->dataType = DataType::STRING_T; $$->isConst = true; $$->sVal = $1; }
    | FLOAT_VAL        { Trace("Reduce: <FLOAT_VAL: " + to_string($1) + "> => <literal>"); $$ = makeNode(); $$->dataType = DataType::FLOAT_T;  $$->isConst = true; $$->dVal = $1; }  
;                       

/* data type: all the data type of the sD programming language */
data_type:
      VOID_TYPE       { Trace("Reduce: void => <data_type>");    $$ = DataType::VOID_T;   }
    | BOOL_TYPE       { Trace("Reduce: bool => <data_type>");    $$ = DataType::BOOL_T;   }
    | FLOAT_TYPE      { Trace("Reduce: float => <data_type>");   $$ = DataType::FLOAT_T;  }
    | INT_TYPE        { Trace("Reduce: int => <data_type>");     $$ = DataType::INT_T;    }
    | STRING_TYPE     { Trace("Reduce: string => <data_type>");  $$ = DataType::STRING_T; }
;

enter_scope:
    /* empty */ { enterScope();}
;

exit_scope:
    /* empty */ { exitScope();}
;
%%


// enter new scope, new a symbol table
void enterScope(){
    if(printSbt){
        cout << "\n> Enter new scope: " << endl;
    }
    SymbolTable* newScope = new SymbolTable(false);
    newScope->parent = sbt;
    sbt->children.push_back(newScope);
    newScope->counter = sbt->counter;
    sbt = newScope;
}


// exit scope, dump symbol table
void exitScope(){
    if(printSbt){
        cout << "\n> Exit current scope, dump symbol table: ";
        sbt->dump();
    }
    sbt = sbt->parent;
}


// yyerror, print error message
void yyerror(string s) {
    cout << "Error: " << s << ", in line " << linenum << endl;
    exit(1);
}


string getClassName(string path){
    int n = path.length();
    int begin = n - 1;
    while(begin >= 0 && path[begin] != '/') begin--;
    begin++;
    int len = 0;
    while(path[begin + len] != '.'){
        len++;
    }
    return path.substr(begin, len);
}

// main function
int main(int argc, char* argv[]) {
    if(argc != 2) {
        printf("Usage: ./parser <sD filename>\n");
        exit(1);
    }

    yyin = fopen(argv[1], "r"); 
    if(!yyin){
        perror("fopen"); 
        exit(1);
    }

    // start parsing
    sbt = new SymbolTable(true);
    string className = getClassName(argv[1]);
    codegen = new CodeGenerator(className);
    yyparse();

    // check main() 
    AstNode* mainFunc = sbt->lookup("main");
    if(mainFunc == nullptr) yyerror("no main function");
    if(!mainFunc->isFunc) yyerror("main is not a function");
    if(mainFunc->dataType != DataType::VOID_T) yyerror("return type of main() is not void");

    if(printSbt){
        cout << endl << "global Symbol Table: ";
        sbt->dump();
    }

    string jasm = codegen->dump();
    if(printJasm){
        cout << jasm << endl;
    }

    // free
    delete sbt; 
    delete codegen;
}
