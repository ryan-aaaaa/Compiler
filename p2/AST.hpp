#ifndef AST_HPP
#define AST_HPP

#include <string>
#include <vector>

using namespace std;

enum DataType{
    UNKNOWN,
    VOID_T,
    BOOL_T,
    CHAR_T,
    FLOAT_T,
    INT_T,
    STRING_T,
    DOUBLE_T
};


typedef struct AstNode{
    // identifier name, if exist
    string name;

    // data type
    DataType dataType;
    
    // value, if exist
    int iVal;
    bool bVal;
    double dVal;
    string sVal;
    vector<int> aiVal;
    vector<bool> abVal;
    vector<double> adVal;
    vector<string> asVal;

    // attribute
    bool isConst;
    bool isArray;
    bool isFunc;

    vector<AstNode*> paramList; // use to store the datatype, isArray, name of parameter of a function
    vector<int> arrayDims;
} AstNode;

AstNode* makeNode();
AstNode* makeNode(const AstNode* node);


string getTypeStr(DataType dataType);


#endif // AST_HPP