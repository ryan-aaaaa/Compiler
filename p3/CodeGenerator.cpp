#include "CodeGenerator.hpp"
#include "AST.hpp"
#include "SymbolTable.hpp"
#include <iostream>
#include <string>
#include <queue>
#include <fstream>

using namespace std;

string CodeGenerator::getClassName(string path){
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

CodeGenerator::CodeGenerator(){
    this->className = "unknown";
    this->jasmStk.clear();
    this->labelCounter = 0;
}

CodeGenerator::CodeGenerator(string path){
    this->className = this->getClassName(path);
    this->jasmStk.clear();
    this->labelCounter = 0;
}

string CodeGenerator::dump(){
    ofstream output(this->className + ".jasm");
    output << this->jasmStk.back();
    output.close();
    return this->jasmStk.back();
}

string CodeGenerator::getNewLabel(){
    return "L" + to_string(this->labelCounter++);
}


void CodeGenerator::enterScope(){
}

void CodeGenerator::exitScope(){
}


void CodeGenerator::generateProgram(){
    string jasm = "";
    while(!this->jasmStk.empty()){
        jasm = this->jasmStk.back() + jasm;
        this->jasmStk.pop_back();
    }
    jasm = "class " + this->className + "\n{\n" + jasm + "}";
    this->jasmStk.push_back(jasm);
}

void CodeGenerator::generateVarDecl(AstNode* node){
    string jasm = "";
    if(node->isGlobal){
        jasm += "field static int " + node->name;
        if(node->isInit) jasm += " = " + to_string(node->iVal);
        jasm += '\n';
    }
    else{
        if(node->isInit) jasm += this->exprDFS(node->children[0]);
        else jasm += "sipush 0\n";
        jasm += "istore " + to_string(node->number) + "\n";
    }
    this->jasmStk.push_back(jasm);
}

void CodeGenerator::generateFuncDecl(AstNode* node){
    string wrapper = "method public static " + getTypeStr(node->dataType) + " " + node->name + "(";
    for(AstNode* param : node->paramList){
        wrapper += getTypeStr(param->dataType) + ", ";
    }
    if(!node->paramList.empty()){
        wrapper.pop_back();
        wrapper.pop_back();
    }
    if(node->name == "main") wrapper += "java.lang.String[]";
    wrapper += ")\n";
    wrapper += "max_stack 1000\nmax_locals 1000\n{\n";
    this->jasmStk.back() = wrapper + this->jasmStk.back();
    if(node->dataType == DataType::VOID_T) this->jasmStk.back() += "return\n";
    this->jasmStk.back() += "}\n";
}

void CodeGenerator::insertEmpty(){
    this->jasmStk.push_back("");
}

void CodeGenerator::combineTopTwo(){
    string tmp = this->jasmStk.back();
    this->jasmStk.pop_back();
    this->jasmStk.back() += tmp;
}


// void print(AstNode* root, int indent){
//     if (!root) return;
//     string pad(indent, ' ');
//     cout << pad
//          << getTypeStr(root->exprType)  // 或 node->name
//          << endl;
//     for (AstNode* child : root->children) {
//         print(child, indent + 2);
//     }
// }

string CodeGenerator::exprDFS(AstNode* node){
    if(node->exprType == ExprType::EXPR_ID){
        cout << "dsaf" << "\n" << node->name << endl;
        if(node->isConst){
            if(node->dataType == DataType::INT_T) return "sipush " + to_string(node->iVal) + "\n";
            if(node->dataType == DataType::BOOL_T) return "iconst_" + to_string(node->iVal) + "\n";
            if(node->dataType == DataType::STRING_T) return "ldc \"" + node->sVal + "\"\n";
        }
        if(node->isGlobal) return "getstatic int " + this->className + "." + node->name + "\n";
        return "iload " + to_string(node->number) + "\n";
    }
    if(node->exprType == ExprType::EXPR_LITERAL){
        if(node->dataType == DataType::INT_T) return "sipush " + to_string(node->iVal) + "\n";
        if(node->dataType == DataType::BOOL_T) return "iconst_" + to_string(node->iVal) + "\n";
        if(node->dataType == DataType::STRING_T) return "ldc \"" + node->sVal + "\"\n"; 
    }
    
    if(node->exprType == ExprType::EXPR_NOT)  return exprDFS(node->children[0]) + "iconst_1\nixor\n";
    if(node->exprType == ExprType::EXPR_INC){
        if(node->isGlobal) return "getstatic int " + this->className + "." + node->name + "\niconst_1\niadd\nputstatic int " + this->className + "." + node->name + "\n";
        else return "iinc " + to_string(node->number) + " 1\n";  
    }
    if(node->exprType == ExprType::EXPR_DEC){
        if(node->isGlobal) return "getstatic int " + this->className + "." + node->name + "\niconst_1\nisub\nputstatic int " + this->className + "." + node->name + "\n";
        else return "iinc " + to_string(node->number) + " -1\n";          
    }
    if(node->exprType == ExprType::EXPR_POS) return "";
    if(node->exprType == ExprType::EXPR_NEG) return exprDFS(node->children[0]) + "ineg\n";

    if(node->exprType == ExprType::EXPR_FUNCCALL){
        string preprocess = "";
        string types = "(";
        for(AstNode* arg: node->children){
            preprocess += exprDFS(arg);
            types += getTypeStr(arg->dataType) + ", ";
        }
        if(node->children.size() != 0){
            types.pop_back();
            types.pop_back();
        }
        types += ")\n";
        return preprocess + "invokestatic " + getTypeStr(node->dataType) + " " + this->className + "." + node->name + types;
    }

        
    string prefix = exprDFS(node->children[0]) + exprDFS(node->children[1]);
    if(node->exprType == ExprType::EXPR_LAND) return prefix + "iand\n";
    if(node->exprType == ExprType::EXPR_LOR)  return prefix + "ior\n";
    if(node->exprType == ExprType::EXPR_ADD)  return prefix + "iadd\n";
    if(node->exprType == ExprType::EXPR_SUB)  return prefix + "isub\n";
    if(node->exprType == ExprType::EXPR_MUL)  return prefix + "imul\n";
    if(node->exprType == ExprType::EXPR_DIV)  return prefix + "idiv\n";
    if(node->exprType == ExprType::EXPR_MOD)  return prefix + "irem\n";

    string L1 = getNewLabel(), L2 = getNewLabel();
    if(node->exprType == ExprType::EXPR_LT)  return prefix + "isub\niflt " + L1 + "\niconst_0\ngoto " + L2 + "\n" + L1 + ": \niconst_1\n" + L2 + ":\nnop\n";   
    if(node->exprType == ExprType::EXPR_GT)  return prefix + "isub\nifgt " + L1 + "\niconst_0\ngoto " + L2 + "\n" + L1 + ": \niconst_1\n" + L2 + ":\nnop\n";  
    if(node->exprType == ExprType::EXPR_LE)  return prefix + "isub\nifle " + L1 + "\niconst_0\ngoto " + L2 + "\n" + L1 + ": \niconst_1\n" + L2 + ":\nnop\n";  
    if(node->exprType == ExprType::EXPR_GE)  return prefix + "isub\nifge " + L1 + "\niconst_0\ngoto " + L2 + "\n" + L1 + ": \niconst_1\n" + L2 + ":\nnop\n";  
    if(node->exprType == ExprType::EXPR_EQ)  return prefix + "isub\nifeq " + L1 + "\niconst_0\ngoto " + L2 + "\n" + L1 + ": \niconst_1\n" + L2 + ":\nnop\n";  
    if(node->exprType == ExprType::EXPR_NEQ) return prefix + "isub\nifne " + L1 + "\niconst_0\ngoto " + L2 + "\n" + L1 + ": \niconst_1\n" + L2 + ":\nnop\n";  
    return "";
}

void CodeGenerator::generateExpr(AstNode* node){   
    this->jasmStk.push_back(this->exprDFS(node));
}


void CodeGenerator::generateAssignment(AstNode* node){
    this->generateExpr(node->children[1]);
    string exprBlock = this->jasmStk.back(); this->jasmStk.pop_back();
    string tmp = exprBlock;
    if(node->children[0]->isGlobal) tmp += "putstatic int " + this->className + "." + node->children[0]->name + "\n";
    else tmp += "istore " + to_string(node->children[0]->number) + "\n";
    this->jasmStk.push_back(tmp);
}

void CodeGenerator::generatePrint(AstNode* node){
    this->generateExpr(node);
    string exprBlock = this->jasmStk.back(); this->jasmStk.pop_back();
    string tmp = "getstatic java.io.PrintStream java.lang.System.out\n" + exprBlock;
    if(node->dataType == DataType::STRING_T) tmp += "invokevirtual void java.io.PrintStream.print(java.lang.String)\n";
    if(node->dataType == DataType::INT_T)    tmp += "invokevirtual void java.io.PrintStream.print(int)\n";
    if(node->dataType == DataType::BOOL_T)   tmp += "invokevirtual void java.io.PrintStream.print(boolean)\n";
    this->jasmStk.push_back(tmp);
}

void CodeGenerator::generatePrintln(AstNode* node){
    this->generateExpr(node);
    string exprBlock = this->jasmStk.back(); this->jasmStk.pop_back();
    string tmp = "getstatic java.io.PrintStream java.lang.System.out\n" + exprBlock;
    if(node->dataType == DataType::STRING_T) tmp += "invokevirtual void java.io.PrintStream.println(java.lang.String)\n";
    if(node->dataType == DataType::INT_T)    tmp += "invokevirtual void java.io.PrintStream.println(int)\n";
    if(node->dataType == DataType::BOOL_T)   tmp += "invokevirtual void java.io.PrintStream.println(boolean)\n";
    this->jasmStk.push_back(tmp);
}



void CodeGenerator::generateIf(AstNode* node){
    this->generateExpr(node);
    string exprBlock = this->jasmStk.back(); this->jasmStk.pop_back();
    string ifBlock = this->jasmStk.back(); this->jasmStk.pop_back();
    string Lfalse = this->getNewLabel();
    string tmp = exprBlock + "ifeq " + Lfalse + "\n" + ifBlock + Lfalse + ": \nnop\n";
    this->jasmStk.push_back(tmp);
}


void CodeGenerator::generateIfElse(AstNode* node){
    this->generateExpr(node);
    string exprBlock = this->jasmStk.back(); this->jasmStk.pop_back();
    string elseBlock = this->jasmStk.back(); this->jasmStk.pop_back();
    string ifBlock = this->jasmStk.back(); this->jasmStk.pop_back();
    string Lfalse = this->getNewLabel(), Lexit = this->getNewLabel();
    string tmp = exprBlock + "ifeq " + Lfalse + "\n" + ifBlock + "goto " + Lexit + "\n" + Lfalse + ": \n" + elseBlock + Lexit + ": \nnop\n";
    this->jasmStk.push_back(tmp);
}

void CodeGenerator::generateWhile(AstNode* node){
    this->generateExpr(node);
    string exprBlock = this->jasmStk.back(); this->jasmStk.pop_back();
    string stmtBlock = this->jasmStk.back(); this->jasmStk.pop_back();
    string Lbegin = this->getNewLabel(), Lexit = this->getNewLabel();

    string tmp = Lbegin + ": \n" + exprBlock + "ifeq " + Lexit + "\n" +  stmtBlock + "goto " + Lbegin + "\n" + Lexit + ": \nnop\n";
    this->jasmStk.push_back(tmp);
}

void CodeGenerator::generateFor(AstNode* node){
    this->generateExpr(node);
    string exprBlock     = this->jasmStk.back(); this->jasmStk.pop_back();
    string stmtBlock     = this->jasmStk.back(); this->jasmStk.pop_back();
    string postStmtBlock = this->jasmStk.back(); this->jasmStk.pop_back();
    string preStmtBlock  = this->jasmStk.back(); this->jasmStk.pop_back();

    string Lbegin = this->getNewLabel(), Lexit = this->getNewLabel();

    string tmp = preStmtBlock + Lbegin + ": \n" + exprBlock + "ifeq " + Lexit + "\n" +  stmtBlock + postStmtBlock + "goto " + Lbegin + "\n" + Lexit + ": \nnop\n";
    this->jasmStk.push_back(tmp);
}


void CodeGenerator::generateForeach(AstNode* node){
    AstNode* id = node->children[0];
    AstNode* a  = node->children[1];
    AstNode* b  = node->children[2];

    string stmtBlock = this->jasmStk.back(); this->jasmStk.pop_back();
    
    AstNode* nodePair = makeNode();
    nodePair->children = {a, b};
    nodePair->exprType = ExprType::EXPR_LT;
    string modeBlock = this->exprDFS(nodePair);
    
    nodePair->children = {id, b};
    nodePair->exprType = ExprType::EXPR_LE;
    string incExprBlock = this->exprDFS(nodePair);
    nodePair->exprType = ExprType::EXPR_GE;
    string decExprBlock = this->exprDFS(nodePair);
    
    id->exprType = ExprType::EXPR_INC;
    string incPostBlock = this->exprDFS(id);
    id->exprType = ExprType::EXPR_DEC;
    string decPostBlock = this->exprDFS(id);

    string preBlock = this->exprDFS(a);
    if(id->isGlobal) preBlock += "putstatic int " + this->className + "." + id->name + "\n";
    else preBlock += "istore " + to_string(id->number) + "\n";
    
    string Lbegin = this->getNewLabel(), LdecExpr = this->getNewLabel(), LexprExit = this->getNewLabel();
    string LdecPost = this->getNewLabel(), LpostExit = this->getNewLabel(), Lexit = this->getNewLabel();

    string tmp = "";
    tmp += modeBlock + preBlock + Lbegin + ": \n";
    tmp += "dup\nifeq " + LdecExpr + "\n" + incExprBlock + "goto " + LexprExit + "\n" + LdecExpr + ": \n" + decExprBlock + LexprExit + ": \n";
    tmp += "ifeq " + Lexit + "\n";
    tmp += stmtBlock;
    tmp += "dup\nifeq " + LdecPost + "\n" + incPostBlock + "goto " + LpostExit + "\n" + LdecPost + ": \n" + decPostBlock + LpostExit + ": \n";  
    tmp += "goto " + Lbegin + "\n";
    tmp += Lexit + ": \npop\nnop\n";

    this->jasmStk.push_back(tmp);
}


void CodeGenerator::generateReturn(AstNode* node){
    if(node->dataType == DataType::VOID_T){
        this->jasmStk.push_back("return\n");
    }
    else{
        this->generateExpr(node);
        string exprBlock = this->jasmStk.back(); this->jasmStk.pop_back();
        this->jasmStk.push_back(exprBlock + "ireturn\n");
    }
}