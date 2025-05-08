#include "AST.hpp"
#include <vector>
#include <string>

using namespace std;


AstNode* makeNode(){
    AstNode* newNode = new AstNode();
    newNode->name = "";
    newNode->dataType = DataType::UNKNOWN;
    
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

    newNode->paramList.clear();
    newNode->arrayDims.clear();
    return newNode;

}

// copy constructor, excluding identifier name 
AstNode* makeNode(const AstNode* node){
    AstNode* newNode = new AstNode();
    newNode->name = "";
    newNode->dataType = node->dataType;
    
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