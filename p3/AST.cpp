#include "AST.hpp"
#include <vector>
#include <string>

using namespace std;


AstNode* makeNode(){
    AstNode* newNode = new AstNode();
    newNode->name = "";
    newNode->dataType = DataType::UNKNOWN;
    newNode->exprType = ExprType::UNKNOWN;
    
    newNode->iVal = 0; 
    newNode->bVal = false;
    newNode->dVal = 0.0;
    newNode->sVal = "";
    newNode->aiVal.clear();
    newNode->abVal.clear();
    newNode->adVal.clear();
    newNode->asVal.clear();

    newNode->isConst = false;
    newNode->isArray = false;
    newNode->isFunc = false;
    newNode->isInit = false;
    newNode->isGlobal = false;

    newNode->number = -1;

    newNode->paramList.clear();
    newNode->arrayDims.clear();
    return newNode;

}

// copy constructor, excluding identifier name 
AstNode* makeNode(const AstNode* node){
    AstNode* newNode = new AstNode();
    newNode->name = "";
    newNode->dataType = node->dataType;
    newNode->exprType = node->exprType;
    
    newNode->iVal = node->iVal; 
    newNode->bVal = node->bVal;
    newNode->dVal = node->dVal;
    newNode->sVal = node->sVal;
    newNode->aiVal = node->aiVal;
    newNode->abVal = node->abVal;
    newNode->adVal = node->adVal;
    newNode->asVal = node->asVal;

    newNode->isConst = node->isConst;
    newNode->isArray = node->isArray;
    newNode->isFunc = node->isFunc;
    newNode->isInit = false;
    newNode->isGlobal = false;

    newNode->number = -1;

    newNode->paramList = node->paramList;
    newNode->arrayDims = node->arrayDims;
    return newNode;
}


string getTypeStr(DataType dataType){
    if(dataType == DataType::BOOL_T) return "bool";
    if(dataType == DataType::INT_T) return "int";
    if(dataType == DataType::FLOAT_T) return "float";
    if(dataType == DataType::STRING_T) return "string";
    if(dataType == DataType::VOID_T) return "void";
    return "unknown";
}


string getTypeStr(ExprType exprType){
    if(exprType == ExprType::UNKNOWN) return            "UNKNOWN";
    if(exprType == ExprType::EXPR_LAND) return          "EXPR_LAND";
    if(exprType == ExprType::EXPR_LOR) return           "EXPR_LOR";
    if(exprType == ExprType::EXPR_NOT) return           "EXPR_NOT";
    if(exprType == ExprType::EXPR_LT) return            "EXPR_LT";
    if(exprType == ExprType::EXPR_GT) return            "EXPR_GT";
    if(exprType == ExprType::EXPR_LE) return            "EXPR_LE";
    if(exprType == ExprType::EXPR_GE) return            "EXPR_GE";
    if(exprType == ExprType::EXPR_EQ) return            "EXPR_EQ";
    if(exprType == ExprType::EXPR_NEQ) return           "EXPR_NEQ";
    if(exprType == ExprType::EXPR_ADD) return           "EXPR_ADD";
    if(exprType == ExprType::EXPR_SUB) return           "EXPR_SUB";
    if(exprType == ExprType::EXPR_MUL) return           "EXPR_MUL";
    if(exprType == ExprType::EXPR_DIV) return           "EXPR_DIV";
    if(exprType == ExprType::EXPR_MOD) return           "EXPR_MOD";
    if(exprType == ExprType::EXPR_INC) return           "EXPR_INC";
    if(exprType == ExprType::EXPR_DEC) return           "EXPR_DEC";
    if(exprType == ExprType::EXPR_POS) return           "EXPR_POS";
    if(exprType == ExprType::EXPR_NEG) return           "EXPR_NEG";
    if(exprType == ExprType::EXPR_BRAC) return          "EXPR_BRAC";
    if(exprType == ExprType::EXPR_FUNCCALL) return      "EXPR_FUNCCALL";
    if(exprType == ExprType::EXPR_ID) return            "EXPR_ID";
    if(exprType == ExprType::EXPR_LITERAL) return        "EXPR_LITERAL";
    return "unknown";
}


