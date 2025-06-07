#ifndef CODE_GENERATOR_HPP
#define CODE_GENERATOR_HPP
#include <iostream>
#include <string>
#include <vector>
#include "AST.hpp"
#include "SymbolTable.hpp"

using namespace std;

class CodeGenerator{
public:
    CodeGenerator();
    CodeGenerator(string path);
    string dump();

    void generateProgram();
    
    void generateVarDecl(AstNode* node);
    void generateFuncDecl(AstNode* node);

    void insertEmpty();
    void combineTopTwo();

    string exprDFS(AstNode* node);
    void generateExpr(AstNode* node);
    void generateAssignment(AstNode* node);
    void generatePrint(AstNode* node);
    void generatePrintln(AstNode* node);
    void generateIf(AstNode* node);
    void generateIfElse(AstNode* node);
    void generateReturn(AstNode* node);
    void generateWhile(AstNode* node);
    void generateFor(AstNode* node);
    void generateForeach(AstNode* node);

private:
    string className;
    string getNewLabel();
    vector<string> jasmStk;
    int labelCounter;
};









#endif // CODE_GENERATOR_HPP