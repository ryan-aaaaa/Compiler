#ifndef AST_HPP
#define AST_HPP

#include <string>
#include <vector>

using namespace std;

enum class DataType{
    UNKNOWN,
    VOID_T,
    BOOL_T,
    CHAR_T,
    FLOAT_T,
    INT_T,
    STRING_T,
    DOUBLE_T
};

enum class ExprType{
    UNKNOWN,
    EXPR_LAND,
    EXPR_LOR,
    EXPR_NOT,
    EXPR_LT,
    EXPR_GT,
    EXPR_LE,
    EXPR_GE,
    EXPR_EQ,
    EXPR_NEQ,
    EXPR_ADD,
    EXPR_SUB,
    EXPR_MUL,
    EXPR_DIV,
    EXPR_MOD,
    EXPR_INC,
    EXPR_DEC,
    EXPR_POS,
    EXPR_NEG,
    EXPR_BRAC,
    EXPR_FUNCCALL,
    EXPR_ID,
    EXPR_LITERAL
};

typedef struct AstNode{
    // identifier name, if exist
    string name;

    // data type
    DataType dataType;
    ExprType exprType;

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
    bool isInit;
    bool isGlobal;

    int number;

    vector<AstNode*> paramList; // use to store the datatype, isArray, name of parameter of a function
    vector<AstNode*> children;
    vector<int> arrayDims;
} AstNode;

AstNode* makeNode();
AstNode* makeNode(const AstNode* node);


string getTypeStr(DataType dataType);
string getTypeStr(ExprType exprType);

#endif // AST_HPP